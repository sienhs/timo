"""Run from an environment with the official Depth-Anything-V2 repo and torch/onnx installed."""
import argparse
import sys
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--repo", type=Path, required=True)
parser.add_argument("--checkpoint", type=Path, required=True)
parser.add_argument("--output", type=Path, default=Path("assets/models/depth_anything_v2_vits.onnx"))
args = parser.parse_args()
sys.path.insert(0, str(args.repo.resolve()))
import torch
from depth_anything_v2.dpt import DepthAnythingV2

# Small / ViT-S only. This is the same tensor contract used by DepthProcessor.kt.
model = DepthAnythingV2(encoder="vits", features=64, out_channels=[48, 96, 192, 384])
model.load_state_dict(torch.load(args.checkpoint, map_location="cpu", weights_only=True))
model.eval()
args.output.parent.mkdir(parents=True, exist_ok=True)
dummy = torch.zeros(1, 3, 518, 518, dtype=torch.float32)
with torch.no_grad():
    torch.onnx.export(model, dummy, str(args.output), input_names=["image"], output_names=["depth"], opset_version=17, dynamo=False)
import onnx
onnx.checker.check_model(onnx.load(str(args.output)))
print("Small model exported and ONNX structure validated.")
