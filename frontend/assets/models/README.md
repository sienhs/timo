# Depth Anything V2 Small

앱이 싣는 모델은 `depth_anything_v2_vits_int8.onnx`(35,615,956바이트)입니다. ONNX Community가 배포한 Depth Anything V2 Small / ViT-S FP32 변환본을 `tools/quantize_depth.py`로 동적 INT8 양자화한 결과이며, Gradle `syncDepthModel`은 이 파일과 출처 JSON, 라이선스만 Android assets에 포함합니다.

## 양자화 (2026-09-10)

- 방법: ONNX Runtime `quantize_dynamic`, `MatMul` 가중치만 per-channel INT8(`MatMulInteger` + `DynamicQuantizeLinear`). Conv·LayerNorm·DPT 헤드는 FP32 유지.
- 크기: 99,060,839 → 35,615,956바이트 (64% 감소). MatMul 가중치가 원본 99MB 중 85MB였습니다.
- 정확도: 데모 이미지 5장에서 FP32 출력과 상관도 0.9949~0.9999, 정규화 후 평균 절대 오차 0.0006~0.0153.
- 호스트 CPU 2스레드 지연: FP32 약 1.25~1.49초 → INT8 약 0.48~1.04초.
- SHA256: `f7b132de541137c0dc2acc818543b8351cbe7961f69cb84fa08c44f36dd6591d`. 같은 원본에서 다시 만들면 같은 값이 나옵니다.
- 출처 메타데이터: `depth_anything_v2_vits_int8.json`.
- FP16은 채택하지 않았습니다. ONNX Runtime 1.23.2 CPU에서 LayerNorm 융합 단계의 Cast 버그로 세션 초기화가 실패하고, CPU에서는 속도 이점도 없습니다.

## FP32 원본 (앱에 포함하지 않음)

`depth_anything_v2_vits.onnx`(99,060,839바이트)는 양자화의 입력으로만 사용하며 APK에 들어가지 않습니다.

- 배포 저장소: https://huggingface.co/onnx-community/depth-anything-v2-small
- 고정 revision: `4472b7362082ad9968fee890ca0f1e5aca36b93d`
- SHA256: `afb6a5c28f3b6bf1618c6e43f02073ef9dfdc70e937502d51603e57b0a1df10c`
- 원본 프로젝트: https://github.com/DepthAnything/Depth-Anything-V2
- 라이선스: Apache-2.0, `DEPTH_ANYTHING_LICENSE.txt` 동봉.
- 출처 메타데이터: `depth_anything_v2_vits.json`.

## 재현

```powershell
python tools/download_depth.py   # FP32 원본 다운로드 또는 크기·SHA256 검증
python tools/quantize_depth.py   # INT8 모델과 출처 JSON 생성
python tools/verify_depth.py     # INT8 실제 추론 + FP32 대비 상관도 검사
```

onnx·onnxruntime(1.23.2 권장, Android 런타임과 동일)·numpy·Pillow가 있는 Python이 필요합니다. 직접 PyTorch에서 변환하려면 기존 `tools/export_depth.py`를 사용합니다.

## 텐서 계약

입력: `pixel_values`, RGB float32 NCHW `[1,3,518,518]`, RGB/255 후 mean=(.485,.456,.406), std=(.229,.224,.225).
출력: `predicted_depth`, float32 `[1,518,518]`, 상대 깊이. 앱은 이를 min/max 정규화해 PNG로 저장합니다. INT8 모델도 같은 계약을 사용하며 입력 양자화는 그래프 안에서 동적으로 처리합니다.

Android는 모델을 캐시 파일로 스트리밍 복사하고 ONNX Runtime이 파일 경로에서 읽습니다. 이전 설치가 남긴 FP32 캐시는 첫 실행에서 삭제합니다. APK 업데이트 시 캐시를 갱신합니다.

INT8과 FP32를 실기기에서 20장으로 비교한 정량 결과(정규화 MAE 0.79%, 3-band 레이어 일치율 98.4%, 추론 804ms 대 1,230ms)는 [모델 선정 근거](../../docs/MODEL_SELECTION.md)와 `verification/model_benchmark/`에 있습니다. 이전 검증 결과는 `verification/depth_v2/`를 참고하세요. 실제 깊이 추론에 실패할 때만 기존 데모 깊이 효과로 대체합니다.
