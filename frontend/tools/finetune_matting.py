"""Fine-tune MODNet on the P3M-10K train split so the shipped cutout matches real portraits.

The upstream photographic checkpoint loses hair and finger detail on the boundary
band the app cares about. This keeps the official architecture and the official
supervised training step, adds the augmentation the upstream trainer leaves to the
caller, and selects on a slice of the train split that is held out. P3M-500-NP is
never touched here: it stays clean for tools/eval_matting.py and
tools/benchmark_models.py.

    python tools/finetune_matting.py fetch     # MODNet source, checkpoint, train shards
    python tools/finetune_matting.py prep      # parquet -> downscaled jpg/png pairs
    python tools/finetune_matting.py train     # writes build/matting_finetune/out

Needs torch with CUDA, torchvision, scipy, pyarrow, pillow. The MODNet trainer
builds a blur layer on the GPU at import time, so a CUDA device is required.
"""
import argparse
import io
import json
import random
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "build/matting_finetune"
SOURCE = WORK / "MODNet"
CKPT = WORK / "ckpt/modnet_photographic_portrait_matting.ckpt"
DATA = WORK / "data"
DATASET = WORK / "dataset"
OUT = WORK / "out"

UPSTREAM = "https://github.com/ZHKKKe/MODNet.git"
CKPT_URL = "https://drive.google.com/uc?export=download&id=1mcr7ALciuAsHCpLnrtG_eop5-EYhbCmz"
PARQUET_BASE = "https://huggingface.co/datasets/nobg/P3M-10K/resolve/main/data"
SHARDS = ["train-00000-of-00011", "train-00001-of-00011"]  # 857 portraits each

SHORT_EDGE = 720   # stored resolution; training crops are taken from this
CROP = 512         # training crop, matches the app's short-edge policy
VAL_COUNT = 150    # held out from the train split for epoch selection
SEED = 0
APP_SHORT_EDGE = 512
APP_MAX_LONG_EDGE = 1024
BOUNDARY_PX = 10

AUGMENTATION = ("random resized crop 512 (scale 0.5-1.0), horizontal flip, "
                "colour jitter 0.25/0.25/0.25/0.04, randomised trimap band 2-12px")


# --------------------------------------------------------------------------- fetch
def fetch(args):
    WORK.mkdir(parents=True, exist_ok=True)
    if not (SOURCE / "src/trainer.py").is_file():
        subprocess.run(["git", "clone", "--depth", "1", UPSTREAM, str(SOURCE)], check=True)
    CKPT.parent.mkdir(parents=True, exist_ok=True)
    if not CKPT.is_file():
        with urllib.request.urlopen(CKPT_URL, timeout=120) as response:
            CKPT.write_bytes(response.read())
    print("checkpoint", CKPT.stat().st_size, "bytes")
    DATA.mkdir(parents=True, exist_ok=True)
    for name in SHARDS:
        target = DATA / f"{name.split('-of-')[0]}.parquet"
        if target.is_file() and target.stat().st_size > 1_000_000:
            print("have", target.name, target.stat().st_size)
            continue
        partial = target.with_suffix(".part")
        with urllib.request.urlopen(f"{PARQUET_BASE}/{name}.parquet", timeout=180) as response, \
                partial.open("wb") as output:
            while chunk := response.read(4 * 1024 * 1024):
                output.write(chunk)
        partial.replace(target)
        print("downloaded", target.name, target.stat().st_size)


# --------------------------------------------------------------------------- prep
def fit(image, short_edge):
    w, h = image.size
    scale = short_edge / min(w, h)
    return image if scale >= 1.0 else image.resize((round(w * scale), round(h * scale)), Image.LANCZOS)


def prep(args):
    import pyarrow.parquet as pq

    for split in ("train", "val"):
        for sub in ("images", "alpha"):
            (DATASET / split / sub).mkdir(parents=True, exist_ok=True)
    rows = []
    for shard in sorted(DATA.glob("train-*.parquet")):
        table = pq.read_table(shard, columns=["image", "mask"])
        images, masks = table.column("image"), table.column("mask")
        for index in range(table.num_rows):
            image, mask = images[index].as_py(), masks[index].as_py()
            rows.append((Path(image["path"]).stem, image["bytes"], mask["bytes"]))
        print("read", shard.name, table.num_rows, flush=True)
    if not rows:
        raise SystemExit(f"no shards in {DATA}; run `fetch` first")

    random.Random(SEED).shuffle(rows)
    for index, (stem, image_bytes, mask_bytes) in enumerate(rows):
        split = "val" if index < VAL_COUNT else "train"
        rgb = fit(Image.open(io.BytesIO(image_bytes)).convert("RGB"), SHORT_EDGE)
        alpha = fit(Image.open(io.BytesIO(mask_bytes)).convert("L"), SHORT_EDGE)
        if rgb.size != alpha.size:
            alpha = alpha.resize(rgb.size, Image.LANCZOS)
        rgb.save(DATASET / split / "images" / f"{stem}.jpg", quality=95)
        alpha.save(DATASET / split / "alpha" / f"{stem}.png")
    (DATASET / "manifest.json").write_text(json.dumps({
        "dataset": "P3M-10K train split (nobg/P3M-10K mirror, MIT)",
        "shards": [s.name for s in sorted(DATA.glob("train-*.parquet"))],
        "total": len(rows), "val_count": VAL_COUNT, "seed": SEED, "short_edge": SHORT_EDGE,
    }, indent=2) + "\n", encoding="utf-8")
    print("prepared", len(rows) - VAL_COUNT, "train,", VAL_COUNT, "val")


# --------------------------------------------------------------------------- train
def app_resize(size):
    """Mirror PortraitMatting.alpha: 512 short edge, 1024 long edge cap, multiples of 32."""
    w, h = size
    scale = min(APP_SHORT_EDGE / min(w, h), APP_MAX_LONG_EDGE / max(w, h))
    return (max(32, int(w * scale) // 32 * 32), max(32, int(h * scale) // 32 * 32))


def train(args):
    import torch
    import torch.nn as nn
    import torch.nn.functional as F
    from scipy.ndimage import binary_dilation, binary_erosion
    from torch.utils.data import DataLoader, Dataset
    from torchvision.transforms import ColorJitter, RandomResizedCrop
    from torchvision.transforms import functional as TF

    sys.path.insert(0, str(SOURCE))
    from src.models.modnet import MODNet
    from src.trainer import supervised_training_iter

    def trimap_from_alpha(alpha, rng):
        """0 background, 0.5 unknown, 1 foreground. The band width is randomised."""
        foreground = alpha > 0.95
        soft = (alpha > 0.05) & (alpha < 0.95)
        radius = rng.randint(2, 12)
        unknown = binary_dilation(soft, iterations=radius) | (
            binary_dilation(foreground, iterations=radius) & ~binary_erosion(foreground, iterations=radius))
        trimap = np.where(foreground, 1.0, 0.0).astype(np.float32)
        trimap[unknown] = 0.5
        return trimap

    class Portraits(Dataset):
        def __init__(self, root):
            self.root = root
            self.items = sorted((root / "images").glob("*.jpg"))
            self.jitter = ColorJitter(brightness=0.25, contrast=0.25, saturation=0.25, hue=0.04)

        def __len__(self):
            return len(self.items)

        def __getitem__(self, index):
            path = self.items[index]
            rng = random.Random(torch.initial_seed() + index)
            image = Image.open(path).convert("RGB")
            alpha = Image.open(self.root / "alpha" / f"{path.stem}.png").convert("L")
            top, left, height, width = RandomResizedCrop.get_params(image, scale=(0.5, 1.0), ratio=(0.85, 1.18))
            image = TF.resized_crop(image, top, left, height, width, [CROP, CROP], TF.InterpolationMode.BILINEAR)
            alpha = TF.resized_crop(alpha, top, left, height, width, [CROP, CROP], TF.InterpolationMode.BILINEAR)
            if rng.random() < 0.5:
                image, alpha = TF.hflip(image), TF.hflip(alpha)
            image = self.jitter(image)
            values = np.asarray(alpha, dtype=np.float32) / 255.0
            return (TF.normalize(TF.to_tensor(image), [0.5] * 3, [0.5] * 3),
                    torch.from_numpy(trimap_from_alpha(values, rng))[None],
                    torch.from_numpy(values)[None])

    def scores(prediction, truth):
        p, g = prediction > 0.5, truth > 0.5
        union = (p | g).sum()
        band = binary_dilation(g, iterations=BOUNDARY_PX) & ~binary_erosion(g, iterations=BOUNDARY_PX)
        band_union = (band & (p | g)).sum()
        return (1.0 if union == 0 else float((p & g).sum() / union),
                1.0 if band_union == 0 else float((band & p & g).sum() / band_union),
                float(np.abs(prediction - truth).mean()))

    @torch.no_grad()
    def validate(modnet):
        # Every validation image has its own shape, so cudnn autotuning would search
        # an algorithm per image and cost seconds each. Training keeps a fixed crop.
        previous = torch.backends.cudnn.benchmark
        torch.backends.cudnn.benchmark = False
        modnet.eval()
        root = DATASET / "val"
        ious, boundaries, maes = [], [], []
        for path in sorted((root / "images").glob("*.jpg")):
            image = Image.open(path).convert("RGB")
            truth = np.asarray(Image.open(root / "alpha" / f"{path.stem}.png").convert("L"), np.float32) / 255.0
            tensor = TF.normalize(TF.to_tensor(image.resize(app_resize(image.size), Image.BILINEAR)),
                                  [0.5] * 3, [0.5] * 3)[None].cuda()
            matte = F.interpolate(modnet(tensor, True)[2], size=truth.shape, mode="bilinear", align_corners=False)
            iou, boundary, mae = scores(matte[0, 0].cpu().numpy(), truth)
            ious.append(iou), boundaries.append(boundary), maes.append(mae)
        modnet.train()
        torch.backends.cudnn.benchmark = previous
        return {"iou": float(np.mean(ious)), "boundary_iou": float(np.mean(boundaries)),
                "soft_mae": float(np.mean(maes)), "count": len(ious)}

    torch.backends.cudnn.benchmark = True
    torch.manual_seed(SEED)
    OUT.mkdir(parents=True, exist_ok=True)
    modnet = nn.DataParallel(MODNet(backbone_pretrained=False)).cuda()
    modnet.load_state_dict(torch.load(CKPT, map_location="cuda", weights_only=True))

    baseline = validate(modnet)
    print("baseline", json.dumps(baseline), flush=True)
    loader = DataLoader(Portraits(DATASET / "train"), batch_size=args.batch_size, shuffle=True,
                        num_workers=args.workers, pin_memory=True, drop_last=True,
                        persistent_workers=args.workers > 0)
    optimizer = torch.optim.SGD(modnet.parameters(), lr=args.lr, momentum=0.9)
    scheduler = torch.optim.lr_scheduler.StepLR(optimizer, step_size=4, gamma=0.3)

    history, best, best_epoch = [{"epoch": 0, **baseline}], baseline["soft_mae"], 0
    for epoch in range(1, args.epochs + 1):
        started, losses = time.time(), []
        for image, trimap, truth in loader:
            parts = supervised_training_iter(modnet, optimizer, image.cuda(), trimap.cuda(), truth.cuda())
            losses.append(float(sum(float(p) for p in parts)))
        scheduler.step()
        measured = validate(modnet)
        measured.update(loss=float(np.mean(losses)), minutes=round((time.time() - started) / 60, 1))
        history.append({"epoch": epoch, **measured})
        print("epoch", epoch, json.dumps(measured), flush=True)
        if measured["soft_mae"] < best:
            best, best_epoch = measured["soft_mae"], epoch
            torch.save(modnet.state_dict(), OUT / "modnet_finetuned.ckpt")
        (OUT / "history.json").write_text(json.dumps(
            {"baseline": baseline, "best_epoch": best_epoch, "args": vars(args),
             "manifest": json.loads((DATASET / "manifest.json").read_text()),
             "augmentation": AUGMENTATION,
             "history": history}, indent=2) + "\n", encoding="utf-8")
    print("best epoch", best_epoch, "soft_mae", best)


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("fetch").set_defaults(run=fetch)
    sub.add_parser("prep").set_defaults(run=prep)
    trainer = sub.add_parser("train")
    trainer.add_argument("--epochs", type=int, default=12)
    trainer.add_argument("--batch-size", type=int, default=4)  # 512 crops fit 6 GB at 4
    trainer.add_argument("--lr", type=float, default=1e-3)     # 10x below the from-scratch recipe
    trainer.add_argument("--workers", type=int, default=4)
    trainer.set_defaults(run=train)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
