"""Quantitative model benchmark for the two on-device AI models.

Segmentation: ML Kit Selfie Segmentation vs MODNet, IoU against P3M-500-NP ground-truth
alpha mattes plus latency. Depth: Depth Anything V2 Small INT8 vs FP32, error and latency.

Subcommands (run in order):
  prepare   pick a fixed subset of P3M-500-NP (build/benchmark/P3M_500_NP.parquet) and demo images
  push      stage inputs (+ FP32 depth model) into the app's files/bench dir on the phone via adb run-as
            then: dart <flutter_tools.snapshot> test --no-pub --no-uninstall integration_test/model_benchmark_test.dart -d <serial>
  pull      fetch bench/out from the phone into build/benchmark/device_out
  clean     delete the staged bench folder from the phone (frees ~0.5 GB of app storage)
  host      run MODNet and both depth models with onnxruntime on this machine (build/benchmark/host_out)
  evaluate  compute metrics -> verification/model_benchmark/{results.json,TABLES.md,*.png}

Requires numpy, Pillow, onnxruntime, pyarrow (build/depth_venv311). No network calls except adb.
"""
import argparse
import io
import json
import random
import shutil
import statistics
import subprocess
import tarfile
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "build/benchmark"
PARQUET = BENCH / "P3M_500_NP.parquet"
P3M = BENCH / "p3m"
STAGE = BENCH / "device"
DEVICE_OUT = BENCH / "device_out"
HOST_OUT = BENCH / "host_out"
REPORT = ROOT / "verification/model_benchmark"
MODELS = ROOT / "assets/models"
INT8 = MODELS / "depth_anything_v2_vits_int8.onnx"
FP32 = MODELS / "depth_anything_v2_vits.onnx"
MODNET = MODELS / "modnet_photographic_portrait_matting_int8.onnx"  # the shipped model
DEMO = ["pose_test.jpg", "pose_upper.jpg", "stage_blue.png", "stage_gold.png", "stage_pink.png"]
PACKAGE = "com.timo.memory_ticket"
ENGINES = ["modnet", "mlkit", "mlkit_raw"]
ENGINE_LABEL = {"modnet": "MODNet (앱 채택)", "mlkit": "ML Kit + 앱 후처리", "mlkit_raw": "ML Kit 원본 confidence"}
EDGE_BAND = 10  # px around the GT boundary


# --------------------------------------------------------------------------- helpers
def adb(serial, *args, binary=False, stdin=None):
    cmd = ["adb", "-s", serial, *args]
    result = subprocess.run(cmd, input=stdin, capture_output=True, check=False)
    if result.returncode != 0:
        raise SystemExit(f"{' '.join(cmd)} failed: {result.stderr.decode(errors='replace')}")
    return result.stdout if binary else result.stdout.decode(errors="replace")


def load_alpha(path):
    return np.asarray(Image.open(path).convert("L"), dtype=np.float32) / 255


def resize_to(array, size):
    return np.asarray(Image.fromarray((array * 255).round().astype(np.uint8)).resize(size, Image.Resampling.BILINEAR),
                      dtype=np.float32) / 255


def dilate(mask, r):
    out = mask.copy()
    for _ in range(r):
        m = out
        n = m.copy()
        n[1:, :] |= m[:-1, :]
        n[:-1, :] |= m[1:, :]
        n[:, 1:] |= m[:, :-1]
        n[:, :-1] |= m[:, 1:]
        out = n
    return out


def erode(mask, r):
    return ~dilate(~mask, r)


def seg_metrics(pred, gt):
    p, g = pred > 0.5, gt > 0.5
    inter, union = np.count_nonzero(p & g), np.count_nonzero(p | g)
    band = dilate(g, EDGE_BAND) & ~erode(g, EDGE_BAND)
    b_inter, b_union = np.count_nonzero(p & g & band), np.count_nonzero((p | g) & band)
    soft = (gt > 0.05) & (gt < 0.95)
    diff = np.abs(pred - gt)
    return {
        "iou": float(inter / max(union, 1)),
        "edgeIou": float(b_inter / max(b_union, 1)),
        "maePct": float(diff.mean() * 100),
        "softMaePct": float(diff[soft].mean() * 100) if soft.any() else None,
        "sadK": float(diff.sum() / 1000),
        "fgRecall": float(inter / max(np.count_nonzero(g), 1)),
        "bgLeakPct": float(np.count_nonzero(p & ~g) / max(np.count_nonzero(~g), 1) * 100),
    }


def normalized(depth):
    return (depth - depth.min()) / max(np.ptp(depth), 1e-9)


def depth_metrics(int8, fp32):
    a, b = normalized(int8), normalized(fp32)
    diff = np.abs(a - b)
    coef = np.polyfit(int8.ravel(), fp32.ravel(), 1)
    aligned = np.polyval(coef, int8)
    band_a = np.clip(np.floor(a * 3), 0, 2)
    band_b = np.clip(np.floor(b * 3), 0, 2)
    return {
        "maePct": float(diff.mean() * 100),
        "rmsePct": float(np.sqrt((diff ** 2).mean()) * 100),
        "maxAbsPct": float(diff.max() * 100),
        "p999AbsPct": float(np.percentile(diff, 99.9) * 100),
        "pearson": float(np.corrcoef(int8.ravel(), fp32.ravel())[0, 1]),
        "alignedRmsePct": float(np.sqrt(((aligned - fp32) ** 2).mean()) / np.ptp(fp32) * 100),
        "within5Pct": float((diff < 0.05).mean() * 100),
        "bandAgreePct": float((band_a == band_b).mean() * 100),
    }


def read_f32(path):
    return np.fromfile(path, dtype="<f4").reshape(518, 518)


def app_downsample(image):
    """Mirror ImageFiles.load: power-of-two subsampling until the long edge is <= 1600."""
    sample = 1
    while max(image.size) / sample > 1600:
        sample *= 2
    return image if sample == 1 else image.resize((image.width // sample, image.height // sample), Image.Resampling.BILINEAR)


def stats(values):
    values = [float(v) for v in values if v is not None]
    if not values:
        return {}
    ordered = sorted(values)
    return {"mean": statistics.fmean(values), "median": statistics.median(values),
            "p90": ordered[min(len(ordered) - 1, int(len(ordered) * 0.9))], "min": ordered[0], "max": ordered[-1], "n": len(values)}


# --------------------------------------------------------------------------- prepare
def prepare(args):
    import pyarrow.parquet as pq
    if not PARQUET.is_file():
        raise SystemExit(f"{PARQUET} missing: download data/P3M_500_NP-00000-of-00001.parquet from huggingface.co/datasets/nobg/P3M-10K")
    table = pq.read_table(PARQUET, columns=["image", "mask"])
    picks = sorted(random.Random(args.seed).sample(range(table.num_rows), args.count))
    for sub in ("images", "alpha"):
        (P3M / sub).mkdir(parents=True, exist_ok=True)
    for sub in ("seg", "depth"):
        shutil.rmtree(STAGE / sub, ignore_errors=True)
        (STAGE / sub).mkdir(parents=True, exist_ok=True)
    ids = []
    images, masks = table.column("image"), table.column("mask")
    for i in picks:
        image, mask = images[i].as_py(), masks[i].as_py()
        stem = Path(image["path"]).stem
        ids.append(stem)
        (P3M / "images" / f"{stem}.jpg").write_bytes(image["bytes"])
        Image.open(io.BytesIO(mask["bytes"])).convert("L").save(P3M / "alpha" / f"{stem}.png")
        shutil.copy(P3M / "images" / f"{stem}.jpg", STAGE / "seg" / f"{stem}.jpg")
    for name in DEMO:
        shutil.copy(ROOT / "assets/demo" / name, STAGE / "depth" / name)
    for stem in ids[: args.depth_count]:
        shutil.copy(P3M / "images" / f"{stem}.jpg", STAGE / "depth" / f"{stem}.jpg")
    (STAGE / "config.json").write_text(json.dumps({"segEngines": ENGINES, "depthRuns": args.depth_runs}, indent=2))
    (BENCH / "selection.json").write_text(json.dumps({
        "dataset": "P3M-500-NP (nobg/P3M-10K mirror, MIT)", "seed": args.seed, "count": args.count,
        "depthCount": args.depth_count, "demo": DEMO, "ids": ids}, indent=2))
    print(f"staged {len(ids)} portraits for segmentation, {len(DEMO) + args.depth_count} images for depth -> {STAGE}")


# --------------------------------------------------------------------------- push / pull
def push(args):
    serial = args.serial
    remote = "/data/local/tmp/timo_bench"
    adb(serial, "shell", f"rm -rf {remote}")
    adb(serial, "push", str(STAGE), remote)
    if args.fp32:
        if not FP32.is_file():
            raise SystemExit(f"{FP32} missing; run tools/download_depth.py")
        adb(serial, "shell", f"mkdir -p {remote}/models")
        adb(serial, "push", str(FP32), f"{remote}/models/fp32.onnx")
    adb(serial, "shell", f"run-as {PACKAGE} sh -c 'rm -rf files/bench; mkdir -p files/bench'")
    try:
        adb(serial, "shell", f"run-as {PACKAGE} sh -c 'cp -r {remote}/. files/bench/'")
    except SystemExit as failure:
        print(f"run-as cp failed ({failure}); streaming files individually")
        for path in STAGE.rglob("*"):
            if path.is_file():
                rel = path.relative_to(STAGE).as_posix()
                adb(serial, "shell", f"run-as {PACKAGE} sh -c 'mkdir -p files/bench/{Path(rel).parent.as_posix()}'")
                adb(serial, "shell", f"run-as {PACKAGE} sh -c 'cat > files/bench/{rel}'", stdin=path.read_bytes())
        if args.fp32:
            adb(serial, "shell", f"run-as {PACKAGE} sh -c 'mkdir -p files/bench/models; cat > files/bench/models/fp32.onnx'",
                stdin=FP32.read_bytes())
    adb(serial, "shell", f"rm -rf {remote}")
    print(adb(serial, "shell", f"run-as {PACKAGE} sh -c 'ls files/bench; ls files/bench/seg | wc -l; ls -la files/bench/models'"))


def pull(args):
    data = adb(args.serial, "exec-out", f"run-as {PACKAGE} tar -cf - -C files/bench out", binary=True)
    shutil.rmtree(DEVICE_OUT, ignore_errors=True)
    DEVICE_OUT.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile() and member.name.startswith("out/"):
                target = DEVICE_OUT / member.name[4:]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.extractfile(member).read())
    props = adb(args.serial, "shell", "getprop ro.product.model; getprop ro.build.version.release; getprop ro.soc.model").split()
    (DEVICE_OUT / "device.json").write_text(json.dumps({"serial": args.serial, "props": props}, indent=2))
    print(f"pulled {sum(1 for _ in DEVICE_OUT.rglob('*') if _.is_file())} files -> {DEVICE_OUT}")


def clean(args):
    before = adb(args.serial, "shell", f"run-as {PACKAGE} sh -c 'du -sm files/bench 2>/dev/null'").strip()
    adb(args.serial, "shell", f"run-as {PACKAGE} sh -c 'rm -rf files/bench'")
    left = adb(args.serial, "shell", f"run-as {PACKAGE} sh -c 'ls files'").split()
    print(f"removed {before or 'files/bench'}; remaining app files: {' '.join(left)}")


# --------------------------------------------------------------------------- host
def session_for(path, threads=2):
    import onnxruntime as ort
    options = ort.SessionOptions()
    options.intra_op_num_threads = threads
    started = time.perf_counter()
    session = ort.InferenceSession(str(path), sess_options=options, providers=["CPUExecutionProvider"])
    return session, (time.perf_counter() - started) * 1000


def host(args):
    import onnxruntime as ort
    selection = json.loads((BENCH / "selection.json").read_text())
    (HOST_OUT / "seg").mkdir(parents=True, exist_ok=True)
    (HOST_OUT / "depth").mkdir(parents=True, exist_ok=True)
    # MODNet, same resolution policy as PortraitMatting.alpha
    session, session_ms = session_for(MODNET)
    seg_results = []
    for n, stem in enumerate(selection["ids"]):
        image = app_downsample(Image.open(P3M / "images" / f"{stem}.jpg").convert("RGB"))
        w, h = image.size
        scale = min(512 / min(w, h), 1024 / max(w, h))
        width, height = max(32, int(w * scale) // 32 * 32), max(32, int(h * scale) // 32 * 32)
        small = np.asarray(image.resize((width, height), Image.Resampling.BILINEAR), dtype=np.float32)
        tensor = ((small - 127.5) / 127.5).transpose(2, 0, 1)[None]
        started = time.perf_counter()
        alpha = session.run(None, {"input": tensor})[0][0, 0]
        infer_ms = (time.perf_counter() - started) * 1000
        full = Image.fromarray((np.clip(alpha, 0, 1) * 255).round().astype(np.uint8)).resize((w, h), Image.Resampling.BILINEAR)
        full.save(HOST_OUT / "seg" / f"{stem}_modnet.png")
        seg_results.append({"engine": "modnet", "image": stem, "inferMs": infer_ms, "sessionMs": session_ms if n == 0 else 0,
                            "totalMs": None, "warmup": n == 0, "width": w, "height": h})
    (HOST_OUT / "segment_results.json").write_text(json.dumps(seg_results))
    # Depth: INT8 vs FP32, same preprocessing as DepthProcessor
    depth_results = []
    sessions = {}
    for tag, path in (("int8", INT8), ("fp32", FP32)):
        if path.is_file():
            sessions[tag] = session_for(path)
    for image_path in sorted((STAGE / "depth").iterdir()):
        image = Image.open(image_path).convert("RGB").resize((518, 518), Image.Resampling.BILINEAR)
        values = np.asarray(image, dtype=np.float32) / 255
        tensor = ((values - [.485, .456, .406]) / [.229, .224, .225]).astype(np.float32).transpose(2, 0, 1)[None]
        for tag, (session, session_ms) in sessions.items():
            run_ms = []
            for _ in range(args.runs + 1):
                started = time.perf_counter()
                depth = session.run(None, {"pixel_values": tensor})[0][0]
                run_ms.append((time.perf_counter() - started) * 1000)
            depth.astype("<f4").tofile(HOST_OUT / "depth" / f"{image_path.stem}_{tag}.f32")
            depth_results.append({"tag": tag, "image": image_path.stem, "sessionMs": session_ms, "runMs": run_ms[1:],
                                  "warmupMs": run_ms[0], "min": float(depth.min()), "max": float(depth.max())})
        print(f"host depth {image_path.name}")
    (HOST_OUT / "depth_results.json").write_text(json.dumps(depth_results))
    import platform
    (HOST_OUT / "device.json").write_text(json.dumps({"host": platform.processor() or platform.machine(), "python": platform.python_version(),
                                                     "onnxruntime": ort.__version__, "threads": 2}, indent=2))
    print(f"host results -> {HOST_OUT}")


# --------------------------------------------------------------------------- evaluate
def evaluate_segmentation(folder):
    path = folder / "segment_results.json"
    if not path.is_file():
        return None
    results = json.loads(path.read_text())
    per_image = {}
    errors = {}
    for r in results:
        if r.get("warmup") or r.get("error"):
            if r.get("error"):
                errors.setdefault(r["engine"], 0)
                errors[r["engine"]] += 1
            continue
        pred_path = folder / "seg" / f"{r['image']}_{r['engine']}.png"
        gt_path = P3M / "alpha" / f"{r['image']}.png"
        if not pred_path.is_file() or not gt_path.is_file():
            continue
        gt = load_alpha(gt_path)
        pred = load_alpha(pred_path)
        if pred.shape != gt.shape:
            pred = resize_to(pred, (gt.shape[1], gt.shape[0]))
        metrics = seg_metrics(pred, gt)
        metrics.update({"inferMs": r.get("inferMs"), "sessionMs": r.get("sessionMs"), "totalMs": r.get("totalMs")})
        per_image.setdefault(r["engine"], {})[r["image"]] = metrics
    engines = [e for e in ENGINES if e in per_image]
    summary = {}
    for engine in engines:
        rows = per_image[engine].values()
        summary[engine] = {key: stats([row[key] for row in rows]) for key in
                           ("iou", "edgeIou", "maePct", "softMaePct", "sadK", "fgRecall", "bgLeakPct", "inferMs", "sessionMs", "totalMs")}
        summary[engine]["errors"] = errors.get(engine, 0)
        summary[engine]["coldStartMs"] = [r.get("totalMs") for r in results if r.get("warmup") and r.get("engine") == engine and not r.get("error")]
    wins = {}
    if "modnet" in per_image and "mlkit" in per_image:
        common = sorted(set(per_image["modnet"]) & set(per_image["mlkit"]))
        diffs = {i: per_image["modnet"][i]["iou"] - per_image["mlkit"][i]["iou"] for i in common}
        wins = {"images": len(common), "modnetBetterIou": int(sum(d > 0 for d in diffs.values())),
                "mlkitBetterIou": int(sum(d < 0 for d in diffs.values())),
                "meanIouGain": statistics.fmean(diffs.values()) if diffs else None,
                "modnetWorstIou": min(per_image["modnet"].values(), key=lambda m: m["iou"])["iou"],
                "mlkitWorstIou": min(per_image["mlkit"].values(), key=lambda m: m["iou"])["iou"],
                "iouDiff": diffs}
    return {"summary": summary, "wins": wins, "perImage": per_image}


def evaluate_depth(folder):
    path = folder / "depth_results.json"
    if not path.is_file():
        return None
    results = json.loads(path.read_text())
    by_tag = {}
    for r in results:
        if r.get("error"):
            continue
        by_tag.setdefault(r["tag"], {})[r["image"]] = r
    fidelity = {}
    if "int8" in by_tag and "fp32" in by_tag:
        for image in sorted(set(by_tag["int8"]) & set(by_tag["fp32"])):
            a, b = folder / "depth" / f"{image}_int8.f32", folder / "depth" / f"{image}_fp32.f32"
            if a.is_file() and b.is_file():
                fidelity[image] = depth_metrics(read_f32(a), read_f32(b))
    latency = {}
    for tag, rows in by_tag.items():
        runs = [ms for r in rows.values() for ms in r.get("runMs", [])]
        latency[tag] = {"runMs": stats(runs), "sessionMs": stats([r.get("sessionMs") for r in rows.values()]),
                        "nativeHeapDeltaMb": stats([r.get("nativeHeapDeltaMb") for r in rows.values()]),
                        "pssMb": stats([r.get("pssMb") for r in rows.values()]), "images": len(rows)}
    summary = {key: stats([m[key] for m in fidelity.values()]) for key in
               ("maePct", "rmsePct", "maxAbsPct", "p999AbsPct", "pearson", "alignedRmsePct", "within5Pct", "bandAgreePct")} if fidelity else {}
    return {"fidelity": fidelity, "fidelitySummary": summary, "latency": latency,
            "modelBytes": {"int8": INT8.stat().st_size if INT8.is_file() else None, "fp32": FP32.stat().st_size if FP32.is_file() else None}}


def fmt(value, digits=1, suffix=""):
    if value is None or value == {}:
        return "-"
    return f"{value:.{digits}f}{suffix}"


def font(size=13):
    for name in ("C:/Windows/Fonts/malgun.ttf", "C:/Windows/Fonts/NanumGothic.ttf", "C:/Windows/Fonts/gulim.ttc"):
        if Path(name).is_file():
            try:
                return ImageFont.truetype(name, size)
            except OSError:
                continue
    return ImageFont.load_default()


def seg_panel(device, target):
    """Rows: image | GT | ML Kit | MODNet for the median, best-for-MODNet and best-for-ML Kit images."""
    diffs = device["wins"].get("iouDiff") or {}
    if not diffs:
        return
    ordered = sorted(diffs, key=diffs.get)
    picks = [("ML Kit 우세", ordered[0]), ("중간값", ordered[len(ordered) // 2]), ("MODNet 우세", ordered[-1])]
    tile = 220
    labels = ["원본", "정답 알파", "ML Kit + 후처리", "MODNet"]
    canvas = Image.new("RGB", (tile * 4 + 10 * 5, (tile + 34) * len(picks) + 30), "white")
    draw = ImageDraw.Draw(canvas)
    face = font()
    for c, label in enumerate(labels):
        draw.text((10 + c * (tile + 10), 8), label, fill="black", font=face)
    for row, (title, image) in enumerate(picks):
        y = 30 + row * (tile + 34)
        sources = [P3M / "images" / f"{image}.jpg", P3M / "alpha" / f"{image}.png",
                   DEVICE_OUT / "seg" / f"{image}_mlkit.png", DEVICE_OUT / "seg" / f"{image}_modnet.png"]
        for c, src in enumerate(sources):
            img = Image.open(src).convert("RGB")
            img.thumbnail((tile, tile))
            canvas.paste(img, (10 + c * (tile + 10), y + 18))
        m, k = device["perImage"]["modnet"][image]["iou"], device["perImage"]["mlkit"][image]["iou"]
        draw.text((10, y + 2), f"{title}  {image}  IoU ML Kit {k:.3f} / MODNet {m:.3f}", fill="black", font=face)
    canvas.save(target)


def depth_panel(folder, fidelity, target):
    if not fidelity:
        return
    ordered = sorted(fidelity, key=lambda i: fidelity[i]["maePct"])
    picks = [ordered[0], ordered[len(ordered) // 2], ordered[-1]]
    tile = 220
    labels = ["원본", "FP32 깊이", "INT8 깊이", "|차이| x5"]
    canvas = Image.new("RGB", (tile * 4 + 50, (tile + 34) * len(picks) + 30), "white")
    draw = ImageDraw.Draw(canvas)
    face = font()
    for c, label in enumerate(labels):
        draw.text((10 + c * (tile + 10), 8), label, fill="black", font=face)
    for row, image in enumerate(picks):
        y = 30 + row * (tile + 34)
        source = next(p for p in (STAGE / "depth").iterdir() if p.stem == image)
        fp32, int8 = normalized(read_f32(folder / "depth" / f"{image}_fp32.f32")), normalized(read_f32(folder / "depth" / f"{image}_int8.f32"))
        tiles = [Image.open(source).convert("RGB"),
                 Image.fromarray((fp32 * 255).astype(np.uint8)).convert("RGB"),
                 Image.fromarray((int8 * 255).astype(np.uint8)).convert("RGB"),
                 Image.fromarray((np.clip(np.abs(fp32 - int8) * 5, 0, 1) * 255).astype(np.uint8)).convert("RGB")]
        for c, img in enumerate(tiles):
            img.thumbnail((tile, tile))
            canvas.paste(img, (10 + c * (tile + 10), y + 18))
        f = fidelity[image]
        draw.text((10, y + 2), f"{image}  정규화 MAE {f['maePct']:.2f}%  Pearson {f['pearson']:.4f}  band 일치 {f['bandAgreePct']:.1f}%", fill="black", font=face)
    canvas.save(target)


def tables(device_seg, host_seg, device_depth, host_depth, device_info, host_info, selection):
    lines = []
    n = device_seg["wins"].get("images") if device_seg else None
    lines += [f"### 세그멘테이션 정확도 (기기: {device_info}, P3M-500-NP {n}장, GT 알파 매트 기준)", "",
              "| 엔진 | IoU 평균 | IoU 중앙값 | 경계 ±10px IoU | 전경 재현율 | 배경 누출 | 소프트 MAE | 반투명 영역 MAE |",
              "|---|---|---|---|---|---|---|---|"]
    if device_seg:
        for engine, s in device_seg["summary"].items():
            lines.append(f"| {ENGINE_LABEL[engine]} | {fmt(s['iou'].get('mean'), 3)} | {fmt(s['iou'].get('median'), 3)} | "
                         f"{fmt(s['edgeIou'].get('mean'), 3)} | {fmt(s['fgRecall'].get('mean') * 100 if s['fgRecall'] else None, 1, '%')} | "
                         f"{fmt(s['bgLeakPct'].get('mean'), 2, '%')} | {fmt(s['maePct'].get('mean'), 2, '%')} | {fmt(s['softMaePct'].get('mean'), 1, '%')} |")
        w = device_seg["wins"]
        if w:
            lines += ["", f"IoU 승패(MODNet vs ML Kit+후처리): MODNet 우세 {w['modnetBetterIou']}장 / ML Kit 우세 {w['mlkitBetterIou']}장 / "
                          f"평균 IoU 차이 {w['meanIouGain']:+.3f} / 최악 사진 IoU MODNet {w['modnetWorstIou']:.3f} vs ML Kit {w['mlkitWorstIou']:.3f}"]
    lines += ["", f"### 세그멘테이션 지연 시간 (기기: {device_info}, 웜업 제외, ms)", "",
              "| 엔진 | 추론 중앙값 | 추론 p90 | 세션 생성 중앙값 | 사진→알파 전체 중앙값 | 전체 p90 | 첫 호출(콜드) |",
              "|---|---|---|---|---|---|---|"]
    if device_seg:
        for engine, s in device_seg["summary"].items():
            cold = s["coldStartMs"][0] if s["coldStartMs"] else None
            lines.append(f"| {ENGINE_LABEL[engine]} | {fmt(s['inferMs'].get('median'), 0)} | {fmt(s['inferMs'].get('p90'), 0)} | "
                         f"{fmt(s['sessionMs'].get('median'), 0)} | {fmt(s['totalMs'].get('median'), 0)} | {fmt(s['totalMs'].get('p90'), 0)} | {fmt(cold, 0)} |")
    if host_seg and "modnet" in host_seg["summary"]:
        s = host_seg["summary"]["modnet"]
        lines += ["", f"호스트 참고({host_info}): MODNet 추론 중앙값 {fmt(s['inferMs'].get('median'), 0)} ms, IoU 평균 {fmt(s['iou'].get('mean'), 3)} "
                      f"(기기 결과와 동일 모델·동일 해상도 정책; ML Kit은 Android 전용이라 호스트 수치 없음)"]
    lines += ["", f"### 깊이 모델 정확도: INT8 vs FP32 (기기: {device_info}, {len(device_depth['fidelity']) if device_depth else 0}장, FP32 출력 기준)", "",
              "| 지표 | 평균 | 중앙값 | 최악 |", "|---|---|---|---|"]
    if device_depth and device_depth["fidelitySummary"]:
        fs = device_depth["fidelitySummary"]
        rows = [("정규화 깊이 MAE", "maePct", 2, "%"), ("정규화 깊이 RMSE", "rmsePct", 2, "%"),
                ("정규화 절대 오차 상위 0.1% 지점", "p999AbsPct", 1, "%"), ("정규화 최대 절대 오차(단일 픽셀)", "maxAbsPct", 1, "%"),
                ("Pearson 상관", "pearson", 4, ""), ("스케일·시프트 정합 후 RMSE", "alignedRmsePct", 2, "%"),
                ("|오차| < 5% 픽셀 비율", "within5Pct", 1, "%"), ("3-band 시차 레이어 일치율", "bandAgreePct", 1, "%")]
        for label, key, d, suffix in rows:
            worst = fs[key].get("min") if key in ("pearson", "within5Pct", "bandAgreePct") else fs[key].get("max")
            lines.append(f"| {label} | {fmt(fs[key].get('mean'), d, suffix)} | {fmt(fs[key].get('median'), d, suffix)} | {fmt(worst, d, suffix)} |")
    lines += ["", "### 깊이 모델 지연 시간·크기", "",
              "| 모델 | 파일 크기 | 기기 추론 중앙값 | 기기 추론 p90 | 기기 세션 생성 중앙값 | 추론 전후 네이티브 힙 차이(누수 점검) | 앱 프로세스 PSS | 호스트 추론 중앙값 |",
              "|---|---|---|---|---|---|---|---|"]
    for tag, name in (("int8", "Depth Anything V2 Small INT8 (앱 채택)"), ("fp32", "Depth Anything V2 Small FP32")):
        d = (device_depth or {}).get("latency", {}).get(tag, {})
        h = (host_depth or {}).get("latency", {}).get(tag, {})
        size = (device_depth or host_depth or {}).get("modelBytes", {}).get(tag)
        lines.append(f"| {name} | {fmt(size / 1048576 if size else None, 1, ' MB')} | {fmt(d.get('runMs', {}).get('median'), 0, ' ms')} | "
                     f"{fmt(d.get('runMs', {}).get('p90'), 0, ' ms')} | {fmt(d.get('sessionMs', {}).get('median'), 0, ' ms')} | "
                     f"{fmt(d.get('nativeHeapDeltaMb', {}).get('median'), 2, ' MB')} | {fmt(d.get('pssMb', {}).get('median'), 0, ' MB')} | "
                     f"{fmt(h.get('runMs', {}).get('median'), 0, ' ms')} |")
    if host_depth and host_depth["fidelitySummary"]:
        fs = host_depth["fidelitySummary"]
        lines += ["", f"호스트 참고({host_info}, {len(host_depth['fidelity'])}장): INT8 vs FP32 정규화 MAE 평균 {fmt(fs['maePct'].get('mean'), 2, '%')}, "
                      f"Pearson 최소 {fmt(fs['pearson'].get('min'), 4)}, band 일치율 평균 {fmt(fs['bandAgreePct'].get('mean'), 1, '%')}"]
    lines += ["", f"데이터: {selection['dataset']}, seed {selection['seed']}, {selection['count']}장 무작위 추출; 깊이는 데모 {len(selection['demo'])}장 + 인물 {selection['depthCount']}장.",
              "PSS는 모델 전용 사용량이 아니라 Flutter 앱 프로세스 전체 값이며, 두 모델 차이만 비교 의미가 있습니다."]
    return "\n".join(lines) + "\n"


def evaluate(args):
    REPORT.mkdir(parents=True, exist_ok=True)
    selection = json.loads((BENCH / "selection.json").read_text())
    device_seg, device_depth = evaluate_segmentation(DEVICE_OUT), evaluate_depth(DEVICE_OUT)
    host_seg, host_depth = evaluate_segmentation(HOST_OUT), evaluate_depth(HOST_OUT)
    device_info = " ".join(json.loads((DEVICE_OUT / "device.json").read_text())["props"]) if (DEVICE_OUT / "device.json").is_file() else "기기 결과 없음"
    host_info = "host CPU, onnxruntime 2 threads" if (HOST_OUT / "device.json").is_file() else "호스트 결과 없음"
    if host_info != "호스트 결과 없음":
        h = json.loads((HOST_OUT / "device.json").read_text())
        host_info = f"{h['host']}, onnxruntime {h['onnxruntime']} {h['threads']}스레드"
    text = tables(device_seg, host_seg, device_depth, host_depth, device_info, host_info, selection)
    (REPORT / "TABLES.md").write_text(text, encoding="utf-8")
    strip = lambda block: None if block is None else {k: v for k, v in block.items() if k != "perImage"}
    (REPORT / "results.json").write_text(json.dumps({
        "generated": time.strftime("%Y-%m-%d %H:%M"), "selection": selection, "device": device_info, "host": host_info,
        "deviceSegmentation": strip(device_seg), "hostSegmentation": strip(host_seg),
        "deviceDepth": device_depth, "hostDepth": host_depth,
        "deviceSegmentationPerImage": device_seg["perImage"] if device_seg else None,
    }, indent=1, ensure_ascii=False), encoding="utf-8")
    if device_seg and device_seg["wins"]:
        seg_panel(device_seg, REPORT / "segmentation_examples.png")
    if device_depth and device_depth["fidelity"]:
        depth_panel(DEVICE_OUT, device_depth["fidelity"], REPORT / "depth_examples.png")
    print(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--count", type=int, default=100)
    p.add_argument("--depth-count", type=int, default=15)
    p.add_argument("--depth-runs", type=int, default=3)
    p.add_argument("--seed", type=int, default=0)
    p.set_defaults(run=prepare)
    p = sub.add_parser("push")
    p.add_argument("--serial", default="R3CY205MV1H")
    p.add_argument("--no-fp32", dest="fp32", action="store_false")
    p.set_defaults(run=push)
    p = sub.add_parser("pull")
    p.add_argument("--serial", default="R3CY205MV1H")
    p.set_defaults(run=pull)
    p = sub.add_parser("clean")
    p.add_argument("--serial", default="R3CY205MV1H")
    p.set_defaults(run=clean)
    p = sub.add_parser("host")
    p.add_argument("--runs", type=int, default=5)
    p.set_defaults(run=host)
    p = sub.add_parser("evaluate")
    p.set_defaults(run=evaluate)
    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
