# TIMO 게이트 (검표 스캐너 앱)

공연장 입구에서 운영자가 관람객의 입장 QR 을 읽어 **입장 / 입장 불가** 를 판정받는
Flutter 앱. 팬 앱(`../frontend`)과 별도 APK 다. 안드로이드만 대응한다.

화면은 하나다 — 스캔 대기 → (확인 중) → 결과(입장 · 입장 불가 · 확인 실패) → 다시 대기.
로그인·공연 선택은 아직 없다. 헤더의 공연명은 목 값이다.

## 실행

```bash
flutter pub get
flutter run                                    # 실기기 권장. 에뮬레이터는 카메라가 없다
flutter run --dart-define=SCAN_API=mock-error  # 매번 '확인 실패' 화면
```

서버 없이 돈다. 팬 앱이 만드는 QR(`timo:entry:<예매ID>:<발급초>:<nonce>`)을 목이 읽어
예매 ID 로 결과를 가른다 — 규칙은 `lib/features/scan/data/mock_scan_api.dart` 주석의 표.
팬 앱을 `--dart-define=TICKET_API=mock` 으로 띄우고 입장 QR 을 이 앱에 대면 결과 화면을
전부 볼 수 있다.

## 구조

```
lib/
├── main.dart
├── app.dart                         # ScanApi 구현 선택 + 테마 + 첫 화면
├── core/
│   ├── network/                     # ApiClient(dio) · ApiException — 팬 앱과 같은 규약
│   └── theme/                       # AppColors · AppTheme
└── features/scan/
    ├── constants.dart               # 시간·치수·문구. 매직 넘버는 전부 여기
    ├── models/                      # GateTarget · VerificationResult(Admitted/Rejected/Undetermined) · RejectReason
    ├── data/                        # ScanApi(인터페이스) · MockScanApi
    ├── state/scan_api_scope.dart    # ScanApi 를 화면에 내려주는 InheritedWidget
    ├── screens/scan_screen.dart     # 카메라 · 중복 인식 차단 · 결과 표시
    └── widgets/                     # ScanViewfinder(조준 틀) · ScanResultView(결과 전체 화면)
```

## 백엔드 연동 시 바꿀 곳

1. `features/scan/data/http_scan_api.dart` 를 `ScanApi` 와 같은 시그니처로 만든다.
   요청: QR 문자열 그대로 + `concertId`. 응답: 200 에 `{ admitted: true }` 또는
   `{ admitted: false, reasonCode: "EXPIRED" }`. **거절은 4xx 가 아니라 200 이다** — 화면이
   상태 코드를 해석하지 않게 하려는 것이다(`scan_api.dart` 주석).
2. `RejectReason.code` 를 서버 코드 목록과 맞춘다. 모르는 코드는 `unknown` 으로 떨어진다.
3. `app.dart` 의 `_scanApiFor` 에 `http` 를 추가하고 기본값으로 바꾼다.
4. 팬 앱의 QR 이 서버 서명 토큰으로 바뀌면 `EntryPayload` 상수와 `MockScanApi` 의 파싱은
   지운다. 앱은 페이로드를 해석하지 않고 그대로 보내야 한다.

## 규칙

팬 앱 README 의 네이밍·테마 규칙과 팀 CONVENTION.md 를 그대로 따른다.
색은 `AppColors` 만 쓴다. 결과 3종은 색 + 아이콘 + 문구를 항상 함께 바꾼다.
