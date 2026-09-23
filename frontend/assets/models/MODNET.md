# MODNet photographic portrait matting

- Official project: https://github.com/ZHKKKe/MODNet
- Official ONNX download reference and inference: https://github.com/ZHKKKe/MODNet/tree/master/onnx
- License: Apache-2.0; code, model and demos covered by upstream README. `MODNET_LICENSE.txt` bundled in APK.
  Fine-tuning data: P3M-10K train split through the nobg/P3M-10K mirror (MIT).
- Shipped file: `modnet_p3m_finetuned_int8.onnx`, 6,734,509 bytes,
  SHA256 `f29b0e32e04bd4fca3fce640fc1a2f5d84c0f26c822a17a37c75d84ff4a07a9c`. Metadata in
  `modnet_p3m_finetuned_int8.json`. `PortraitMatting.keepMain` drops blobs detached from the subject.
- Official weights, kept in the repo and not packaged: `modnet_photographic_portrait_matting_int8.onnx`,
  6,656,860 bytes, SHA256 `e8c0a9ca88df6724a93ffc160ad53604e85a4bb81b7ba9eefd37e3bca7da9e6d`.
  Rolling back means pointing `PortraitMatting` and the `syncMattingModel` task at it again.
- Official FP32 source (not in the repo, `.gitignore`): `modnet_photographic_portrait_matting.onnx`,
  25,888,640 bytes, SHA256 `07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9`.
- Reproduce the official INT8: `python tools/download_matting.py`, then `python tools/quantize_matting.py`.
- Reproduce the shipped file: `python tools/finetune_matting.py fetch|prep|train`, then
  `python tools/export_matting.py`. Compare with `python tools/eval_matting.py`.

## Fine-tuning on P3M-10K, shipped 2026-09-23

The upstream checkpoint was fine-tuned on the P3M-10K train split with
the official `src.trainer.supervised_training_iter`, plus the augmentation the upstream
trainer leaves to the caller (random resized 512 crops, horizontal flip, colour jitter,
randomised trimap band). 1,714 portraits from 2 of 11 shards, 150 held out for epoch
selection; P3M-500-NP was not used for training. SGD 1e-3, batch 4, 12 epochs, ~24 min
on an RTX 4050. The export keeps opset 11 and the same tensor contract.

The fine-tuned weights alone over-segment: they pick up bystanders, watermark fragments and
background blobs apart from the subject, worst case 0.996 -> 0.844. `PortraitMatting.keepMain`
zeroes every 8-connected blob of alpha > 12/255 smaller than 0.3x the largest, on the
model-resolution alpha, so two people of similar size both stay. `tools/benchmark_models.py`
carries the same filter as `keep_main`.

Host CPU 2 threads, against the official INT8:

| Metric | Official | Fine-tuned | Fine-tuned + keepMain |
|---|---|---|---|
| IoU mean, fixed 100 | 0.9669 | 0.9737 | 0.9768 |
| Boundary +/-10px IoU, fixed 100 | 0.8187 | 0.8710 | 0.8710 |
| Semi-transparent MAE, fixed 100 | 19.31% | 15.47% | 15.48% |
| Background leak, fixed 100 | 1.846% | 1.716% | 1.503% |
| Better / worse, fixed 100 | - | 73 / 27 | 77 / 23 |
| Worst per-image IoU drop, fixed 100 | - | -0.152 | -0.052 |

On all 500 P3M-500-NP images the filtered model is better on 408 and worse on 92. The
remaining regressions touch the subject (objects held or worn, gaps between limbs, windblown
hair), so the filter cannot reach them; crowds pressed against the subject are not covered by
P3M and still need a check on real concert photos. See
`docs/memory/verification/matting_finetune/REPORT.md`.

## INT8 weights, 2026-09-16

The APK carried the FP32 export unchanged (25.9 MB). The 71 Conv/MatMul weight tensors are 25 MB of
that, so they are now stored as per-channel symmetric INT8 with an fp32 scale and rebuilt in the graph
as `Cast(int8 -> float) -> Mul(scale)`. ONNX Runtime constant-folds both nodes at session creation, so
inference runs the original FP32 operators with the same tensor contract. No session option and no
change to the Kotlin inference path; only the asset name, size and checksum changed.

Host CPU 2 threads, onnxruntime 1.23.2, demo photos, against the FP32 output:

| Photo | IoU (0.5 threshold) | Soft MAE | FP32 ms | INT8 ms |
|---|---|---|---|---|
| person_a.png | 0.9993 | 0.0004 | 384 | 374 |
| person_b.png | 0.9997 | 0.0004 | 364 | 373 |
| pose_test.jpg | 0.9958 | 0.0004 | 307 | 315 |
| pose_upper.jpg | 0.9789 | 0.0037 | 363 | 369 |

Interleaved on the same session pair, median latency was 362 ms (FP32) against 361 ms (INT8). The
device benchmark (`tools/benchmark_models.py`, P3M-500-NP, Galaxy S25) has not been rerun with this
file yet; `MODNET` in that tool now points at the shipped INT8 model.

Rejected on the same day:

- `quantize_dynamic` on Conv. INT8 weights produce `ConvInteger` nodes with no CPU kernel in
  ONNX Runtime 1.23.2; UINT8 weights run but collapse accuracy (IoU 0.35-0.49 on the demo people).
- `DequantizeLinear` on the weights. Same numbers as the shipped file, but ORT leaves DQ nodes
  unfolded by default so Conv weights are not pre-packed (about +30% latency) unless the app sets
  `session.disable_quant_qdq`.
- `quantize_static` (QDQ, UINT8 activations, per-channel weights). About 40% faster on host with
  IoU 0.982-0.995 after calibrating on the 4 demo photos plus flips. A candidate for a later
  latency pass, but it needs a real calibration set and the device benchmark before it can ship.

Input `input` is RGB float32 NCHW `[1,3,H,W]`, normalized `(RGB - 127.5) / 127.5`. Dimensions are multiples of 32, 512 short edge with a 1024 long edge limit. Output `output` is float32 `[1,1,H,W]` alpha. Soft alpha is bilinearly resized to the oriented source resolution without threshold sharpening or neighbour erosion. Transparent outer bounds are trimmed with the existing source-crop coordinate contract.

Android uses ONNX Runtime 1.23.2 CPU with two intra-op threads. The bundled file streams to a checksum-named cache path; session and native outputs close after each photo. There are no model/image network calls from the app. ML Kit is an explicit fallback only if model loading/inference fails; runtime exceptions are not represented as successful MODNet results.

## Benchmark, 2026-09-15

Measured against ML Kit Selfie Segmentation on 100 P3M-500-NP portraits with ground-truth alpha mattes,
on a Galaxy S25 (SM-S936N) through the production code path. MODNet mean IoU 0.970 vs 0.944, boundary
(+/-10px) IoU 0.824 vs 0.682, better on 91 of 100 images; median photo-to-alpha latency 549 ms vs 135 ms.
Tables, per-image numbers and the reproduction command: `docs/MODEL_SELECTION.md`,
`verification/model_benchmark/`, `tools/benchmark_models.py`.

## Validation, 2026-09-10

The user's raised-hand photo was compared locally against its previous ML Kit cutout. At 512 short-edge inference, the raised fingers remain visible and excess background around the sleeve is reduced. The 768 setting did not improve the visible result and was slower, so 512 was selected. This is a photo-specific observation, not a general benchmark or a guarantee for all backgrounds.

Galaxy S25 / SM-S936N regression: real native inference, `engine == modnet`, all five foreground sample points inside the raised fingers have alpha >160/255; three background sample points have alpha <25/255. Test passed; segmentation plus result readback took 2,186ms. Raw native output is retained in local `verification/segmentation/modnet_device.png`. No photo upload was used. Saved tickets and app data were preserved with `--no-uninstall`.

Local analysis passed; seven existing creation/depth checks passed. Test command for the local regression photo already present on the device:

```powershell
dart C:/flutter/bin/cache/flutter_tools.snapshot test --no-pub --no-uninstall integration_test/segmentation_quality_test.dart -d R3CY205MV1H
```

The regression references a local user photo and is not a portable bundled fixture. Stored cutouts do not change retrospectively; selecting a photo again runs the new model. Manual brush code remains unused, with no entry point in the creation screen.
