"""Compress the pinned FP32 MODNet export to INT8 weights for the app.

The 71 Conv/MatMul weight tensors are 25 MB of the 25.9 MB FP32 model. They are stored
as per-channel symmetric INT8 with an fp32 scale, and rebuilt in the graph as
`Cast(int8 -> float) -> Mul(scale)`. ONNX Runtime constant-folds both at session
creation, so inference runs the original FP32 graph: same speed, same operators,
same tensor contract, no session option. Measured on host CPU 2 threads the
result is 25,888,640 -> ~6.66 MB with IoU >= 0.979 against FP32 on the demo photos.

Rejected alternatives (2026-09-16, onnxruntime 1.23.2):
- quantize_dynamic on Conv: int8 weights -> ConvInteger has no CPU kernel;
  uint8 weights run but collapse accuracy (IoU 0.35-0.49 on the demo people).
- DequantizeLinear on weights: same numbers as this file, but ORT keeps DQ nodes
  unfolded by default so Conv weights cannot be pre-packed (about +30% latency)
  unless the app sets session.disable_quant_qdq.
- quantize_static (QDQ, u8 activations): ~40% faster on host but needs a proper
  calibration set and a device benchmark before it can replace this file.

Requires onnx and onnxruntime (1.23.2, same as Android). Deterministic: the same
source yields the same SHA256.
"""
import hashlib
import json
import logging
import sys
import time
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
from onnx import TensorProto, helper, numpy_helper
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from download_matting import SHA256 as SOURCE_SHA256, TARGET as SOURCE, verified  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "assets/models/modnet_photographic_portrait_matting_int8.onnx"
DEMO = ["person_a.png", "person_b.png", "pose_test.jpg", "pose_upper.jpg"]
MIN_IOU = 0.97
MAX_MAE = 0.01
SETTINGS = {"method": "weight-only INT8, per-channel symmetric, Cast+Mul rebuilt in graph",
            "op_types": ["Conv", "MatMul"], "weight_type": "int8", "per_channel": True,
            "activations": "fp32 (unchanged)", "compute": "fp32 after ONNX Runtime constant folding"}


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def compress(model):
    initializers = {i.name: i for i in model.graph.initializer}
    prologue = []
    for node in model.graph.node:
        if node.op_type not in SETTINGS["op_types"] or node.input[1] not in initializers:
            continue
        name = node.input[1]
        weight = numpy_helper.to_array(initializers[name]).astype(np.float32)
        axis = 0 if node.op_type == "Conv" else weight.ndim - 1  # Conv [O,I,kh,kw]; MatMul [K,N]
        reduce_axes = tuple(i for i in range(weight.ndim) if i != axis)
        scale = (np.maximum(np.abs(weight).max(axis=reduce_axes, keepdims=True), 1e-8) / 127.0).astype(np.float32)
        quantized = np.clip(np.round(weight / scale), -127, 127).astype(np.int8)
        model.graph.initializer.remove(initializers[name])
        model.graph.initializer.append(numpy_helper.from_array(quantized, name + "_int8"))
        model.graph.initializer.append(numpy_helper.from_array(scale, name + "_scale"))
        prologue.append(helper.make_node("Cast", [name + "_int8"], [name + "_float"], name=name + "_cast", to=TensorProto.FLOAT))
        prologue.append(helper.make_node("Mul", [name + "_float", name + "_scale"], [name], name=name + "_scale_mul"))
    nodes = prologue + list(model.graph.node)
    del model.graph.node[:]
    model.graph.node.extend(nodes)
    return len(prologue) // 2


def preprocess(path):
    """Same policy as PortraitMatting.alpha: 512 short edge, 1024 long edge cap, multiples of 32."""
    image = Image.open(path).convert("RGB")
    w, h = image.size
    scale = min(512 / min(w, h), 1024 / max(w, h))
    width, height = max(32, int(w * scale) // 32 * 32), max(32, int(h * scale) // 32 * 32)
    values = np.asarray(image.resize((width, height), Image.Resampling.BILINEAR), dtype=np.float32) / 127.5 - 1
    return values.transpose(2, 0, 1)[None]


def session(path):
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    return ort.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])


def verify():
    reference, compressed = session(SOURCE), session(TARGET)
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
        print(f"  {name:16s} IoU vs FP32 {iou:.4f}  MAE {mae:.4f}  fp32 {fp32_ms[-1]:.0f} ms  int8 {int8_ms[-1]:.0f} ms")
    assert worst_iou >= MIN_IOU and worst_mae <= MAX_MAE, (worst_iou, worst_mae)
    return {"images": DEMO, "min_iou_vs_fp32": round(float(worst_iou), 4), "max_mae_vs_fp32": round(worst_mae, 4),
            "host_median_ms": {"fp32": round(float(np.median(fp32_ms))), "int8": round(float(np.median(int8_ms)))}}


def main():
    if not verified(SOURCE):
        raise SystemExit(f"{SOURCE} missing or not the pinned FP32 export; run tools/download_matting.py first")
    logging.getLogger().setLevel(logging.ERROR)
    model = onnx.load(str(SOURCE))
    count = compress(model)
    assert count == 71, count
    onnx.checker.check_model(model)
    assert [i.name for i in model.graph.input] == ["input"]
    assert [o.name for o in model.graph.output] == ["output"]
    partial = TARGET.with_suffix(".onnx.part")
    onnx.save(model, str(partial))
    partial.replace(TARGET)
    print(f"Compressed {count} weight tensors; checking against FP32 on demo photos:")
    check = verify()
    digest = sha256(TARGET)
    metadata = {
        "model": "MODNet photographic portrait matting, INT8 weights",
        "source": {"file": SOURCE.name, "sha256": SOURCE_SHA256, "bytes": 25888640,
                   "export": "https://github.com/ZHKKKe/MODNet/tree/master/onnx"},
        "quantization": SETTINGS,
        "tool": f"tools/quantize_matting.py, onnxruntime {ort.__version__}",
        "sha256": digest,
        "bytes": TARGET.stat().st_size,
        "verification": check,
        "runtime": "ONNX Runtime >= 1.23.2 CPU execution provider",
        "input": "input: RGB float32 NCHW, (RGB - 127.5) / 127.5, multiples of 32",
        "output": "output: float32 [1,1,H,W], alpha in [0,1]",
        "license": "Apache-2.0",
        "upstream": "https://github.com/ZHKKKe/MODNet",
    }
    TARGET.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Compressed model: {metadata['bytes']} bytes, SHA256 {digest}")


if __name__ == "__main__":
    main()
