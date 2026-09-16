# 모델 선정 근거

작성일: 2026-09-15. 측정 기기: Galaxy S25 (SM-S936N), Android 16, SM8750. 호스트: Windows x86_64, onnxruntime 1.23.2 CPU 2스레드.

앱이 온디바이스에서 쓰는 두 모델을 정량 비교한 결과입니다. 누끼는 **ML Kit Selfie Segmentation 대 MODNet**을 공개 정답 알파 매트 기준 IoU와 지연 시간으로, 깊이는 **Depth Anything V2 Small INT8 대 FP32**를 FP32 출력 기준 오차와 추론 시간으로 측정했습니다. 모든 수치는 실기기에서 앱이 실제로 쓰는 코드 경로(`PortraitMatting.alpha`, `PersonProcessor.selfieAlpha`, `DepthProcessor`)를 그대로 호출해 얻었습니다.

재현 절차와 원자료는 [벤치마크 재현](#재현) 및 `verification/model_benchmark/`를 참고하세요.

## 1. 결론

| 항목 | 선정 | 핵심 근거 |
|---|---|---|
| 인물 누끼 | **MODNet** (실패 시 ML Kit 대체) | IoU 평균 0.944 → 0.970, 경계 ±10px IoU 0.682 → 0.824. 100장 중 91장에서 우세 |
| 깊이 추정 | **Depth Anything V2 Small 동적 INT8** | FP32 대비 정규화 MAE 0.79%, 3-band 시차 레이어 일치율 98.4%. 모델 94.5MB → 34.0MB, 추론 1,230ms → 804ms |

두 선택 모두 "정확도를 사는 대신 시간을 낸다"가 아니라, 누끼는 정확도를 얻고 시간을 내주며(ML Kit 대비 +414ms), 깊이는 시간과 용량을 줄이고 오차를 거의 내주지 않는(MAE 0.79%) 반대 방향의 거래입니다.

## 2. 세그멘테이션: ML Kit 대 MODNet

### 측정 조건

- 데이터: **P3M-500-NP** 검증 세트에서 seed 0으로 무작위 추출한 100장. 사람이 만든 알파 매트가 정답으로 들어 있습니다. 출처는 [P3M-10K](https://github.com/JizhiziLi/P3M) (MIT), Hugging Face 미러 `nobg/P3M-10K`.
- 세 가지 구성을 모두 같은 사진에 돌렸습니다: MODNet, ML Kit에 앱의 후처리(이웃 다수결 정리 + smoothstep)를 얹은 것, ML Kit 원본 confidence.
- 정답과 예측 모두 0.5에서 이진화해 IoU를 구하고, 알파 값 자체의 차이는 MAE로 따로 봤습니다.
- 지연 시간은 앱과 동일하게 ONNX Runtime CPU 2스레드, 짧은 변 512px 정책입니다. 첫 호출(콜드)은 따로 기록하고 통계에서 제외했습니다.

### 정확도

| 엔진 | IoU 평균 | IoU 중앙값 | 경계 ±10px IoU | 전경 재현율 | 배경 누출 | 소프트 MAE | 반투명 영역 MAE |
|---|---|---|---|---|---|---|---|
| **MODNet (앱 채택)** | **0.970** | **0.988** | **0.824** | **99.3%** | **1.81%** | **1.56%** | **18.8%** |
| ML Kit + 앱 후처리 | 0.944 | 0.968 | 0.682 | 97.8% | 2.42% | 2.16% | 30.8% |
| ML Kit 원본 confidence | 0.944 | 0.968 | 0.683 | 97.8% | 2.41% | 2.35% | 27.4% |

- 승패: MODNet 우세 91장 / ML Kit 우세 9장 / 평균 IoU 차이 **+0.026**.
- 가장 큰 차이는 **경계 품질**입니다. 정답 윤곽 ±10px 띠에서만 계산한 IoU가 0.682 → 0.824로 벌어집니다. 티켓은 인물을 배경 위에 얹는 합성이라 이 띠가 곧 눈에 보이는 품질입니다.
- 반투명 영역(정답 알파 0.05~0.95, 머리카락·옷 가장자리) MAE도 30.8% → 18.8%로 줄어듭니다. 앱이 알파를 이진화하지 않고 그대로 쓰는 이유가 여기 있습니다.
- 앱의 ML Kit 후처리는 IoU를 바꾸지 않고(0.944 동일) 소프트 MAE만 2.35% → 2.16%로 낮춥니다. 즉 후처리는 잡티 제거용이고, 경계 정확도를 끌어올리지는 못합니다.
- 최악 사진은 MODNet 0.598, ML Kit 0.680으로 MODNet이 더 나쁩니다. 어두운 배경에 몸 윤곽이 묻히는 사진에서 MODNet이 팔 안쪽을 배경으로 판정했습니다(`segmentation_examples.png` 첫 줄). 평균이 좋다고 모든 사진에서 이기지는 않으며, 이 때문에 ML Kit 대체 경로를 남겨 둡니다.

### 지연 시간

| 엔진 | 추론 중앙값 | 추론 p90 | 세션 생성 중앙값 | 사진→알파 전체 중앙값 | 전체 p90 | 첫 호출(콜드) |
|---|---|---|---|---|---|---|
| MODNet (앱 채택) | 481 ms | 729 ms | 40 ms | 549 ms | 829 ms | 563 ms |
| ML Kit + 앱 후처리 | 36 ms | 47 ms | 0 ms | 135 ms | 411 ms | 130 ms |
| ML Kit 원본 confidence | 35 ms | 48 ms | 0 ms | 66 ms | 164 ms | 45 ms |

- MODNet은 ML Kit보다 사진 한 장당 **약 0.41초** 더 걸립니다(전체 중앙값 549ms 대 135ms).
- 이 비용은 티켓 제작 중 1~2회만 발생합니다. 제작은 이미 여러 초가 걸리는 일괄 작업이고 진행 화면(`ProcessingStage`)이 떠 있으므로, 프레임 예산을 잡아먹는 실시간 경로가 아닙니다. 반대로 결과 누끼는 소장품에 영구 저장되어 계속 보입니다.
- ML Kit 후처리는 이웃 다수결 루프 때문에 추론(36ms)보다 후처리가 더 걸립니다(전체 135ms). 원본 confidence만 쓰면 66ms입니다.

### 판정

경계 IoU +0.141과 반투명 영역 오차 12%p 감소를, 제작 1회당 0.41초로 삽니다. 한 번 만들면 수정할 수 없는 소장품이라는 제품 규칙 때문에 이 거래를 택했습니다. ML Kit은 제거하지 않고, 모델 로드나 추론이 실패할 때만 쓰는 명시적 대체 경로로 남깁니다(`PersonProcessor.segment`의 `catch`, 사용자에게 "기본 누끼로 처리했어요" 표시).

### 용량: INT8 가중치판 (2026-09-16 추가)

위 측정은 FP32 export(25.9MB)로 했습니다. 이후 APK 용량을 줄이기 위해 Conv·MatMul 가중치 71개를 채널별 대칭 INT8로 저장하고 그래프 안에서 `Cast → Mul`로 복원하는 `modnet_photographic_portrait_matting_int8.onnx`(6.66MB, 74% 감소)로 교체했습니다. ONNX Runtime이 세션 생성 시 두 노드를 상수 접기하므로 실제 연산은 FP32 그래프 그대로이고, 세션 옵션이나 Kotlin 추론 경로 변경은 없습니다.

호스트(onnxruntime 1.23.2 CPU 2스레드)에서 데모 인물 사진 4장을 FP32 출력과 비교한 결과 IoU 0.979~0.9997, 소프트 MAE 0.04~0.37%, 같은 세션 쌍을 교차 실행한 중앙값 지연은 362ms 대 361ms로 차이가 없습니다. 동적 양자화(ConvInteger)는 int8 가중치에 CPU 커널이 없고 uint8은 IoU가 0.35~0.49로 무너져 제외했으며, 정적 QDQ 양자화는 호스트에서 40% 빨랐지만 캘리브레이션 데이터와 기기 벤치마크가 없어 보류했습니다. 상세는 `assets/models/MODNET.md`, 재현은 `tools/quantize_matting.py`.

**이 파일로 위 P3M 100장 기기 벤치마크는 아직 다시 돌리지 않았습니다.** `tools/benchmark_models.py`의 `MODNET`은 배포 파일을 가리키도록 바꿔 두었으므로, [재현](#재현) 절차를 그대로 실행하면 INT8판 수치가 나옵니다.

## 3. 깊이: INT8 대 FP32

### 측정 조건

- 이미지 20장(데모 배경·인물 5장 + P3M 인물 15장), 모델당 3회 추론, 같은 세션에서 반복.
- 두 모델 모두 기기에서 같은 전처리(518×518, ImageNet mean/std)를 씁니다. FP32 원본은 APK에 넣지 않고 측정을 위해 기기 앱 저장소로만 전송했습니다.
- 정확도는 FP32 출력을 기준으로, 두 출력을 각각 min-max 정규화한 뒤 비교했습니다. 앱이 상대 깊이를 정규화해 쓰므로 이 방식이 실제 영향과 맞습니다.

### 정확도 (FP32 기준)

| 지표 | 평균 | 중앙값 | 최악 |
|---|---|---|---|
| 정규화 깊이 MAE | 0.79% | 0.58% | 2.58% |
| 정규화 깊이 RMSE | 1.24% | 0.87% | 3.37% |
| 정규화 절대 오차 상위 0.1% 지점 | 6.7% | 6.4% | 13.3% |
| 정규화 최대 절대 오차(단일 픽셀) | 24.7% | 23.6% | 47.3% |
| Pearson 상관 | 0.9991 | 0.9998 | 0.9953 |
| 스케일·시프트 정합 후 RMSE | 0.85% | 0.58% | 2.41% |
| \|오차\| < 5% 픽셀 비율 | 97.6% | 99.9% | 84.6% |
| **3-band 시차 레이어 일치율** | **98.4%** | **99.4%** | **91.3%** |

- 평균 오차는 깊이 범위의 0.79%입니다. 픽셀의 97.6%가 5% 이내에 들어옵니다.
- 최대 절대 오차 24.7%는 사진당 단일 픽셀 값이고, 상위 0.1% 지점은 6.7%입니다. 오차가 넓게 퍼진 게 아니라 경계의 극소수 픽셀에 몰려 있습니다.
- 앱에 직접 이어지는 지표는 마지막 줄입니다. `DepthProcessor.process`는 깊이를 3개 시차 밴드로 나누므로, **같은 픽셀이 같은 밴드에 들어갈 확률 98.4%**가 곧 화면에서 보이는 차이입니다. 최악 사진도 91.3%입니다.
- 호스트에서 같은 20장을 돌린 값도 같은 방향입니다: MAE 평균 0.55%, Pearson 최소 0.9960, 밴드 일치율 98.8%.

### 지연 시간·크기

| 모델 | 파일 크기 | 기기 추론 중앙값 | 기기 추론 p90 | 기기 세션 생성 | 앱 프로세스 PSS | 호스트 추론 중앙값 |
|---|---|---|---|---|---|---|
| **INT8 (앱 채택)** | **34.0 MB** | **804 ms** | **857 ms** | **210 ms** | **500 MB** | **563 ms** |
| FP32 | 94.5 MB | 1,230 ms | 1,286 ms | 306 ms | 513 MB | 793 ms |

- 추론 **-35%**(1,230 → 804ms), 세션 생성 **-31%**(306 → 210ms), APK 내 모델 용량 **-64%**(94.5 → 34.0MB).
- 앱 프로세스 PSS는 13MB 차이입니다. 이 값은 모델 전용 사용량이 아니라 Flutter 프로세스 전체이므로 두 모델의 차이만 의미가 있습니다.
- 추론 전후 네이티브 힙 차이는 두 모델 모두 0.01MB로, 세션·텐서가 호출마다 정상 해제됩니다.

### 판정

밴드 일치율 98.4%는 사용자가 보는 시차 레이어가 사실상 동일하다는 뜻이고, 그 대가로 APK 60MB와 추론 426ms를 회수합니다. INT8을 채택합니다. FP32는 양자화 입력과 이 비교의 기준으로만 `assets/models/`에 남기고 APK에는 넣지 않습니다(Gradle `syncDepthModel`의 include 목록).

FP16은 후보에서 제외했습니다. ONNX Runtime 1.23.2 CPU에서 `SimplifiedLayerNormFusion`의 Cast 버그로 세션 초기화 자체가 실패하며, CPU에서는 속도 이점도 없습니다. per-tensor INT8과 NNAPI 비교를 포함한 이전 후보 표는 `verification/depth_v2/REPORT.md`에 있습니다(NNAPI는 1,015개 노드 중 48개만 1노드 파티션으로 수용해 CPU보다 느렸습니다).

## 4. 시각 비교

- `verification/model_benchmark/segmentation_examples.png`: ML Kit 우세 / 중앙값 / MODNet 우세 사진 각 1장에 대한 원본·정답·ML Kit·MODNet 알파.
- `verification/model_benchmark/depth_examples.png`: 오차 최소·중앙값·최대 사진의 FP32·INT8 깊이와 5배 증폭한 차이 영상.

## 5. 한계

- 세그멘테이션 100장은 P3M-500-NP에서 뽑은 인물 사진입니다. 공연장 조명·역광·다중 인물 같은 이 앱의 실제 사용 조건을 그대로 대표하지는 않습니다.
- 정답 알파가 있는 공개 데이터가 필요해 P3M을 썼고, 사용자의 실제 사진으로는 정답이 없어 IoU를 계산할 수 없습니다. 사용자 사진에 대한 개별 확인은 `integration_test/segmentation_quality_test.dart`의 손가락 회귀 테스트로 남아 있습니다.
- 깊이 비교는 FP32 대비 상대 오차입니다. FP32 자체의 절대 깊이 정확도(실측 거리 대비)는 측정하지 않았습니다. 앱은 상대 깊이만 쓰므로 범위 밖입니다.
- 지연 시간은 Galaxy S25 1대에서 각 조건 1회분 측정입니다. 저사양 기기나 발열 상태에서는 달라질 수 있습니다.
- 사진은 외부로 전송하지 않았습니다. 모든 추론은 기기와 이 PC에서 로컬로 실행했습니다.

## 재현

```powershell
# 1. 정답 데이터 (약 279MB, 1회)
curl -L -o build/benchmark/P3M_500_NP.parquet `
  "https://huggingface.co/datasets/nobg/P3M-10K/resolve/main/data/P3M_500_NP-00000-of-00001.parquet"

# 2. 표본 추출 및 기기 전송
build/depth_venv311/Scripts/python.exe tools/benchmark_models.py prepare --count 100 --depth-count 15
build/depth_venv311/Scripts/python.exe tools/benchmark_models.py push --serial R3CY205MV1H

# 3. 기기 측정 (약 4분)
dart C:/flutter/bin/cache/flutter_tools.snapshot test --no-pub --no-uninstall `
  integration_test/model_benchmark_test.dart -d R3CY205MV1H

# 4. 회수·호스트 측정·표 생성
build/depth_venv311/Scripts/python.exe tools/benchmark_models.py pull --serial R3CY205MV1H
build/depth_venv311/Scripts/python.exe tools/benchmark_models.py host --runs 5
build/depth_venv311/Scripts/python.exe tools/benchmark_models.py evaluate

# 5. 기기에 올린 측정용 데이터 삭제 (약 200MB)
build/depth_venv311/Scripts/python.exe tools/benchmark_models.py clean --serial R3CY205MV1H
```

기기 측정은 `flutter test`의 호스트–기기 연결이 중간에 끊겨 "did not complete"로 멈출 수 있습니다. 앱 프로세스는 살아 있고 그때까지 쓴 파일도 남으므로, 끊기면 같은 명령을 다시 실행하면 됩니다. 동시에 다른 `flutter`/`adb` 명령을 돌리지 않을 때 완주 확률이 높았습니다. 2026-09-15 측정은 100장 전체와 깊이 20장을 3분 46초에 완주한 실행의 결과이며, 이후 부분 재실행에서 같은 사진의 알파 PNG가 바이트 단위로 동일함을 확인했습니다.

산출물은 `verification/model_benchmark/`에 생성됩니다: `TABLES.md`(위 표의 원본), `results.json`(사진별 전체 지표), 비교 이미지 2장. 측정용 네이티브 진입점은 `BenchmarkProcessor.kt`와 메서드 채널 `benchmarkSegment`/`benchmarkDepth`이며 앱 UI에서는 호출되지 않습니다.
