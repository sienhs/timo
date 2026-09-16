"""Quantize the pinned FP32 Depth Anything V2 Small export to dynamic INT8 for the app.

The 72 MatMul weights are 85 MB of the 99 MB FP32 model. They become per-channel INT8
(MatMulInteger + DynamicQuantizeLinear); Conv, LayerNorm and the DPT head stay FP32.
FP16 was rejected: ONNX Runtime 1.23.2 CPU fails to initialize the fp16 graph
(SimplifiedLayerNormFusion cast bug) and CPU fp16 is not faster anyway.

Requires onnx and onnxruntime. Deterministic: the same source yields the same SHA256.
"""
import hashlib
import json
import logging
import sys
from pathlib import Path

import onnx
from onnxruntime.quantization import QuantType, quantize_dynamic

sys.path.insert(0, str(Path(__file__).resolve().parent))
from download_depth import SHA256 as SOURCE_SHA256, TARGET as SOURCE, verified  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "assets/models/depth_anything_v2_vits_int8.onnx"
SETTINGS = {"method": "onnxruntime.quantization.quantize_dynamic", "op_types": ["MatMul"],
            "weight_type": "QInt8", "per_channel": True, "activations": "uint8 (DynamicQuantizeLinear)"}


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main():
    if not verified(SOURCE):
        raise SystemExit(f"{SOURCE} missing or not the pinned FP32 export; run tools/download_depth.py first")
    logging.getLogger().setLevel(logging.ERROR)  # silence the optional pre-processing hint
    partial = TARGET.with_suffix(".onnx.part")
    quantize_dynamic(str(SOURCE), str(partial), op_types_to_quantize=SETTINGS["op_types"],
                     weight_type=QuantType.QInt8, per_channel=True)
    model = onnx.load(str(partial))
    onnx.checker.check_model(model)
    ops = {node.op_type for node in model.graph.node}
    assert {"MatMulInteger", "DynamicQuantizeLinear"} <= ops, ops
    assert [i.name for i in model.graph.input] == ["pixel_values"]
    assert [o.name for o in model.graph.output] == ["predicted_depth"]
    partial.replace(TARGET)
    digest = sha256(TARGET)
    metadata = {
        "model": "Depth Anything V2 Small (ViT-S), dynamic INT8",
        "source": {"file": SOURCE.name, "sha256": SOURCE_SHA256,
                   "export": "onnx-community/depth-anything-v2-small, FP32"},
        "quantization": SETTINGS,
        "tool": f"tools/quantize_depth.py, onnxruntime {__import__('onnxruntime').__version__}",
        "sha256": digest,
        "bytes": TARGET.stat().st_size,
        "runtime": "ONNX Runtime >= 1.23.2 CPU execution provider",
        "license": "Apache-2.0",
        "upstream": "https://github.com/DepthAnything/Depth-Anything-V2",
    }
    TARGET.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Quantized model: {metadata['bytes']} bytes, SHA256 {digest}")


if __name__ == "__main__":
    main()
