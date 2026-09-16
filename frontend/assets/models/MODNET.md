# MODNet photographic portrait matting

- Official project: https://github.com/ZHKKKe/MODNet
- Official ONNX download reference and inference: https://github.com/ZHKKKe/MODNet/tree/master/onnx
- License: Apache-2.0; code, model and demos covered by upstream README. `MODNET_LICENSE.txt` bundled in APK.
- File: `modnet_photographic_portrait_matting.onnx`, 25,888,640 bytes.
- SHA256: `07c308cf0fc7e6e8b2065a12ed7fc07e1de8febb7dc7839d7b7f15dd66584df9`.
- Reproduce download and verify: `python tools/download_matting.py`.

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
