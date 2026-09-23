"""Export a fine-tuned MODNet checkpoint to the ONNX contract the app already uses.

Writes the FP32 export and then the INT8 file, reusing tools/quantize_matting.py
for the compression so the fine-tuned and shipped models are built the same way.
The graph keeps opset 11, the `input`/`output` names and the dynamic height and
width axes, so nothing in PortraitMatting has to change to load the result.

    python tools/export_matting.py

Needs torch with CUDA (the upstream export path builds the model on the GPU),
onnx and onnxruntime.
"""
import argparse
import importlib.util
import json
import logging
import sys
import time
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
import torch.nn as nn

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from finetune_matting import AUGMENTATION, DATASET  # noqa: E402
from quantize_matting import SETTINGS, compress, preprocess, session, sha256  # noqa: E402

WORK = ROOT / "build/matting_finetune"
SOURCE = WORK / "MODNet"
OUT = WORK / "out"
DEMO = ["person_a.png", "person_b.png", "pose_test.jpg", "pose_upper.jpg"]
OPSET = 11  # matches the pinned upstream export
WEIGHT_TENSORS = 71


def load_export_model():
    """MODNet/onnx/modnet_onnx.py is the single-output variant used for export.

    It is loaded by path on purpose: putting the MODNet tree on sys.path would let
    its `onnx/` package directory shadow the real `onnx` package that the exporter
    itself imports.
    """
    sys.path.append(str(SOURCE))
    spec = importlib.util.spec_from_file_location("modnet_onnx", SOURCE / "onnx/modnet_onnx.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def export(ckpt, target):
    modnet_onnx = load_export_model()
    modnet = nn.DataParallel(modnet_onnx.MODNet(backbone_pretrained=False)).cuda()
    missing, unexpected = modnet.load_state_dict(torch.load(ckpt, map_location="cuda", weights_only=True),
                                                 strict=False)
    assert not missing and not unexpected, (missing, unexpected)
    modnet.eval()
    torch.onnx.export(
        modnet.module, torch.randn(1, 3, 512, 512).cuda(), str(target),
        export_params=True, opset_version=OPSET, dynamo=False,
        input_names=["input"], output_names=["output"],
        dynamic_axes={"input": {0: "batch_size", 2: "height", 3: "width"},
                      "output": {0: "batch_size", 2: "height", 3: "width"}})
    print("exported", target.name, target.stat().st_size, "bytes")


def verify(source, target):
    reference, compressed = session(source), session(target)
    worst_iou, worst_mae, fp32_ms, int8_ms = 1.0, 0.0, [], []
    for name in DEMO:
        tensor = preprocess(ROOT / "assets/demo" / name)
        started = time.perf_counter()
        expected = reference.run(None, {"input": tensor})[0]
        fp32_ms.append((time.perf_counter() - started) * 1000)
        started = time.perf_counter()
        actual = compressed.run(None, {"input": tensor})[0]
        int8_ms.append((time.perf_counter() - started) * 1000)
        a, b = actual > 0.5, expected > 0.5
        iou = (a & b).sum() / max(1, (a | b).sum())
        mae = float(np.abs(actual - expected).mean())
        worst_iou, worst_mae = min(worst_iou, iou), max(worst_mae, mae)
        print(f"  {name:16s} IoU vs FP32 {iou:.4f}  MAE {mae:.4f}")
    return {"images": DEMO, "min_iou_vs_fp32": round(float(worst_iou), 4),
            "max_mae_vs_fp32": round(worst_mae, 4),
            "host_median_ms": {"fp32": round(float(np.median(fp32_ms))),
                               "int8": round(float(np.median(int8_ms)))}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ckpt", default=str(OUT / "modnet_finetuned.ckpt"))
    parser.add_argument("--fp32", default=str(OUT / "modnet_finetuned_fp32.onnx"))
    parser.add_argument("--int8", default=str(OUT / "modnet_finetuned_int8.onnx"))
    args = parser.parse_args()
    ckpt, fp32, int8 = Path(args.ckpt), Path(args.fp32), Path(args.int8)
    if not ckpt.is_file():
        raise SystemExit(f"{ckpt} missing; run tools/finetune_matting.py train first")

    logging.getLogger().setLevel(logging.ERROR)
    export(ckpt, fp32)
    model = onnx.load(str(fp32))
    count = compress(model)
    assert count == WEIGHT_TENSORS, count
    onnx.checker.check_model(model)
    assert [i.name for i in model.graph.input] == ["input"]
    assert [o.name for o in model.graph.output] == ["output"]
    onnx.save(model, str(int8))
    print(f"compressed {count} weight tensors -> {int8.stat().st_size} bytes")

    check = verify(fp32, int8)
    history = json.loads((OUT / "history.json").read_text())
    int8.with_suffix(".json").write_text(json.dumps({
        "model": "MODNet photographic portrait matting, fine-tuned on P3M-10K, INT8 weights",
        "source": {"file": fp32.name, "sha256": sha256(fp32), "bytes": fp32.stat().st_size,
                   "export": "tools/export_matting.py, opset 11"},
        "finetune": {
            "base": "official modnet_photographic_portrait_matting.ckpt",
            "data": json.loads((DATASET / "manifest.json").read_text()),
            "augmentation": AUGMENTATION,
            "recipe": "official src.trainer.supervised_training_iter, SGD momentum 0.9, StepLR",
            "args": history["args"], "best_epoch": history["best_epoch"],
        },
        "quantization": SETTINGS,
        "tool": f"tools/export_matting.py (reuses quantize_matting.compress), onnxruntime {ort.__version__}",
        "sha256": sha256(int8), "bytes": int8.stat().st_size,
        "verification": check,
        "runtime": "ONNX Runtime >= 1.23.2 CPU execution provider",
        "input": "input: RGB float32 NCHW, (RGB - 127.5) / 127.5, multiples of 32",
        "output": "output: float32 [1,1,H,W], alpha in [0,1]",
        "license": "Apache-2.0", "upstream": "https://github.com/ZHKKKe/MODNet",
    }, indent=2) + "\n", encoding="utf-8")
    print("wrote", int8.with_suffix(".json").name)


if __name__ == "__main__":
    main()
