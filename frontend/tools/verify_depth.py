"""Check the ONNX contract, run real images through the bundled model, and compare to FP32.

Requires onnx, onnxruntime, numpy and Pillow. Does not call external APIs.
Default: verifies the shipped INT8 model against the pinned FP32 source when it exists.
"""
import argparse
import json
import time
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
INT8 = ROOT / "assets/models/depth_anything_v2_vits_int8.onnx"
FP32 = ROOT / "assets/models/depth_anything_v2_vits.onnx"
DEMO = ["pose_test.jpg", "pose_upper.jpg", "stage_blue.png", "stage_gold.png", "stage_pink.png"]
MIN_CORRELATION = 0.99


def preprocess(path):
    image = Image.open(path).convert("RGB").resize((518, 518), Image.Resampling.BILINEAR)
    values = np.asarray(image).astype(np.float32) / 255
    tensor = ((values - np.array([.485, .456, .406], dtype=np.float32)) /
              np.array([.229, .224, .225], dtype=np.float32)).transpose(2, 0, 1)[None]
    return image, tensor


def session_for(path):
    onnx.checker.check_model(str(path))
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    return ort.InferenceSession(str(path), sess_options=options, providers=["CPUExecutionProvider"])


def timed_run(session, tensor):
    started = time.perf_counter()
    depth = session.run(None, {session.get_inputs()[0].name: tensor})[0]
    return depth, time.perf_counter() - started


def normalized(depth):
    return (depth - depth.min()) / np.ptp(depth)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=INT8)
    parser.add_argument("--reference", type=Path, default=FP32, help="FP32 model for fidelity comparison")
    parser.add_argument("--image", type=Path, default=ROOT / "assets/demo/pose_test.jpg")
    parser.add_argument("--tag", default=None, help="verification/depth_v2/<tag>; defaults to int8 or fp32")
    args = parser.parse_args()
    tag = args.tag or ("int8" if "int8" in args.model.name else "fp32")
    session = session_for(args.model)
    image, tensor = preprocess(args.image)
    timed_run(session, tensor)  # warm-up; the app pays this once per ticket too
    depth, elapsed = timed_run(session, tensor)
    assert depth.shape == (1, 518, 518), depth.shape
    assert np.isfinite(depth).all()
    assert np.ptp(depth) > .00001
    pixels = (normalized(depth[0]) * 255).round().astype(np.uint8)
    horizontal_changes = int(np.count_nonzero(np.diff(pixels.astype(np.int16), axis=1)))
    assert horizontal_changes > 100, "Output resembles a demo ramp"
    folder = ROOT / "verification/depth_v2" / tag
    folder.mkdir(parents=True, exist_ok=True)
    Image.fromarray(pixels).save(folder / "host_depth.png")
    image.save(folder / "host_input.png")
    report = {
        "runtime": ort.__version__, "provider": "CPUExecutionProvider",
        "model": args.model.relative_to(ROOT).as_posix(), "bytes": args.model.stat().st_size,
        "input": {"name": session.get_inputs()[0].name, "shape": list(tensor.shape)},
        "output": {"name": session.get_outputs()[0].name, "shape": list(depth.shape)},
        "min": float(depth.min()), "max": float(depth.max()),
        "horizontalChanges": horizontal_changes, "inferenceSeconds": round(elapsed, 3),
        "source": args.image.relative_to(ROOT).as_posix(),
    }
    compare = args.reference and args.reference.is_file() and args.reference.resolve() != args.model.resolve()
    if compare:
        reference = session_for(args.reference)
        fidelity = []
        for name in DEMO:
            _, demo = preprocess(ROOT / "assets/demo" / name)
            expected, reference_seconds = timed_run(reference, demo)
            actual, model_seconds = timed_run(session, demo)
            correlation = float(np.corrcoef(expected.ravel(), actual.ravel())[0, 1])
            assert correlation > MIN_CORRELATION, (name, correlation)
            fidelity.append({
                "image": name, "correlation": round(correlation, 5),
                "normalizedMeanAbsError": round(float(np.abs(normalized(expected) - normalized(actual)).mean()), 4),
                "referenceSeconds": round(reference_seconds, 3), "modelSeconds": round(model_seconds, 3),
            })
        report["reference"] = {"model": args.reference.relative_to(ROOT).as_posix(), "bytes": args.reference.stat().st_size,
                               "minCorrelation": MIN_CORRELATION, "fidelity": fidelity}
    (folder / "host_verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
