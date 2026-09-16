"""Fetch the pinned FP32 Depth Anything V2 Small ONNX export and verify it."""
import hashlib
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = "4472b7362082ad9968fee890ca0f1e5aca36b93d"
SHA256 = "afb6a5c28f3b6bf1618c6e43f02073ef9dfdc70e937502d51603e57b0a1df10c"
SIZE = 99060839
URL = f"https://huggingface.co/onnx-community/depth-anything-v2-small/resolve/{REVISION}/onnx/model.onnx"
TARGET = ROOT / "assets/models/depth_anything_v2_vits.onnx"


def verified(path):
    if not path.is_file() or path.stat().st_size != SIZE:
        return False
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest() == SHA256


def main():
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    if not verified(TARGET):
        partial = TARGET.with_suffix(".onnx.part")
        with urllib.request.urlopen(URL, timeout=120) as response, partial.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
        if not verified(partial):
            raise RuntimeError("Model size or SHA256 mismatch; original model was not replaced")
        partial.replace(TARGET)
    metadata = {
        "model": "Depth Anything V2 Small (ViT-S)",
        "export": "onnx-community/depth-anything-v2-small, FP32",
        "revision": REVISION,
        "url": URL,
        "sha256": SHA256,
        "bytes": SIZE,
        "license": "Apache-2.0",
        "upstream": "https://github.com/DepthAnything/Depth-Anything-V2",
    }
    TARGET.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Verified Depth Anything V2 Small: {SIZE} bytes, SHA256 {SHA256}")


if __name__ == "__main__":
    main()
