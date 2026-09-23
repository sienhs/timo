"""Compare MODNet ONNX models on the fixed P3M-500-NP subset, host CPU, app preprocessing.

The image selection and every metric come from tools/benchmark_models.py, so these
numbers line up with the published tables; only the model file changes between
rows. Run `python tools/benchmark_models.py prepare` first to stage the subset.

    python tools/eval_matting.py \
        shipped=assets/models/modnet_photographic_portrait_matting_int8.onnx \
        finetuned=build/matting_finetune/out/modnet_finetuned_int8.onnx

A name ending in `+main` runs the same model with `benchmark_models.keep_main`, the
connected-component filter PortraitMatting applies to drop blobs detached from the subject:

    python tools/eval_matting.py finetuned=... finetuned+main=...

With two models it also prints the per-image win count and the largest moves in
both directions, which is what tells a real gain apart from an averaged-out one.
"""
import argparse
import json
import statistics
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import benchmark_models as B  # noqa: E402
from quantize_matting import preprocess, session  # noqa: E402

P3M = ROOT / "build/benchmark/p3m"
SELECTION = ROOT / "build/benchmark/selection.json"
EXTREMES = 5
def run(model_path, stems, main=False):
    inference = session(model_path)
    rows, times = [], []
    for stem in stems:
        tensor = preprocess(P3M / "images" / f"{stem}.jpg")
        started = time.perf_counter()
        alpha = inference.run(None, {"input": tensor})[0][0, 0].clip(0, 1)
        if main:
            alpha = B.keep_main(alpha)
        times.append((time.perf_counter() - started) * 1000)
        truth = B.load_alpha(P3M / "alpha" / f"{stem}.png")
        prediction = B.resize_to(alpha, (truth.shape[1], truth.shape[0]))
        rows.append(B.seg_metrics(prediction, truth))
    return rows, times


def summarize(name, rows, times):
    values = lambda key: [row[key] for row in rows if row[key] is not None]
    return {
        "model": name, "count": len(rows),
        "iou_mean": round(float(np.mean(values("iou"))), 4),
        "iou_median": round(float(np.median(values("iou"))), 4),
        "edge_iou_mean": round(float(np.mean(values("edgeIou"))), 4),
        "fg_recall_mean": round(float(np.mean(values("fgRecall"))), 4),
        "bg_leak_pct_mean": round(float(np.mean(values("bgLeakPct"))), 3),
        "mae_pct_mean": round(float(np.mean(values("maePct"))), 3),
        "soft_mae_pct_mean": round(float(np.mean(values("softMaePct"))), 3),
        "infer_ms_median": round(statistics.median(times)),
    }


def compare(stems, before, after):
    delta = {stem: after[stem] - before[stem] for stem in stems}
    order = sorted(stems, key=lambda stem: delta[stem])
    entry = lambda stem: {"image": stem, "before": round(before[stem], 4),
                          "after": round(after[stem], 4), "delta": round(delta[stem], 4)}
    return {
        "improved": sum(1 for stem in stems if delta[stem] > 0),
        "regressed": sum(1 for stem in stems if delta[stem] < 0),
        "mean_delta": round(float(np.mean(list(delta.values()))), 4),
        "median_delta": round(float(np.median(list(delta.values()))), 4),
        "worst_regressions": [entry(stem) for stem in order[:EXTREMES]],
        "largest_gains": [entry(stem) for stem in order[-EXTREMES:][::-1]],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("models", nargs="+", help="name=path pairs, paths relative to frontend/")
    parser.add_argument("--out", default=str(ROOT / "build/matting_finetune/out/host_eval.json"))
    args = parser.parse_args()
    if not SELECTION.is_file():
        raise SystemExit(f"{SELECTION} missing; run `python tools/benchmark_models.py prepare` first")

    selection = json.loads(SELECTION.read_text())
    stems = selection["ids"]
    print(f"{len(stems)} images, seed {selection['seed']}, {selection['dataset']}", flush=True)

    results, per_image = [], {}
    for spec in args.models:
        name, path = spec.split("=", 1)
        rows, times = run(ROOT / path, stems, main=name.endswith("+main"))
        results.append(summarize(name, rows, times))
        per_image[name] = {stem: row["iou"] for stem, row in zip(stems, rows)}
        print(json.dumps(results[-1]), flush=True)

    report = {"selection": {key: selection[key] for key in ("dataset", "seed", "count")},
              "results": results, "per_image_iou": per_image}
    if len(results) == 2:
        first, second = results[0]["model"], results[1]["model"]
        report["comparison"] = compare(stems, per_image[first], per_image[second])
        print(f"{second} better on {report['comparison']['improved']}/{len(stems)}, "
              f"mean IoU delta {report['comparison']['mean_delta']:+.4f}", flush=True)

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("wrote", args.out)


if __name__ == "__main__":
    main()
