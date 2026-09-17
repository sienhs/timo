# TIMO 게이트 (검표 스캐너 앱)

공연장 입구에서 운영자가 관람객의 입장 QR 을 읽어 **입장 / 입장 불가** 를 판정받는
Flutter 앱. 팬 앱(`../frontend`)과 별도 APK 다. 안드로이드만 대응한다.

화면은 둘이다 — **운영자 로그인** → 스캔 대기 → (확인 중) → 결과(입장 · 입장 불가 · 확인 실패)
→ 다시 대기. 로그인은 **관리자(`ADMIN`) 계정만** 통과한다. 공연 선택은 아직 없다.
헤더의 공연명과 검표 요청에 실리는 `concertId` 는 목 값(`MockScanApi.target`)이다.

## 실행

```bash
flutter pub get
flutter run                                    # 실기기 권장. 에뮬레이터는 카메라가 없다
flutter run --dart-define=AUTH_API=mock --dart-define=SCAN_API=mock   # 서버 없이 끝까지
flutter run --dart-define=SCAN_API=mock-error  # 매번 '확인 실패' 화면
```

기본값은 로그인·검표 모두 실제 서버다(주소는 `API_BASE_URL`, 팬 앱과 같은 백엔드).
- 로그인: `/api/v1/auth/login`. `AUTH_API=mock` 이면 아이디 `admin` 은 관리자, 그 외 아이디는
  팬 계정(로그인 거절), 비밀번호 `wrong1234` 는 틀린 비밀번호다.
- 검표: `POST /api/v1/gates/entries/verify` 에 `{ qr, concertId }`. 관리자 토큰이 필요하며
  `AuthInterceptor` 가 붙인다. `SCAN_API=mock` 이면 팬 앱이 만드는
  QR(`timo:entry:<예매ID>:<발급초>:<nonce>`)을 목이 읽어 예매 ID 로 결과를 가른다 — 규칙은
  `lib/features/scan/data/mock_scan_api.dart` 주석의 표. 팬 앱을 `--dart-define=TICKET_API=mock`
  으로 띄우고 입장 QR 을 이 앱에 대면 결과 화면을 전부 볼 수 있다.

## 로그인 동작

- 서버 로그인 API 는 역할을 보지 않고 누구든 로그인시킨다. 앱이 받은 액세스 토큰(JWT)의
  `roles` 클레임을 읽어(`AccessTokenClaims`) `ADMIN` 이 아니면 세션에 담지 않고 방금 생긴
  서버 세션도 로그아웃으로 끊는다. 이 판정은 안내용이다 — 검증 요청이 진짜 관리자에게서
  왔는지는 서버가 토큰 서명으로 가려낸다.
- 로그인 정보는 안드로이드 Keystore(`flutter_secure_storage`)에 저장돼 앱을 다시 켜도 유지된다.
- 토큰이 만료되면 `AuthInterceptor` 가 조용히 재발급받아 요청을 이어간다. 재발급까지 실패하면
  로그아웃 상태가 되어 로그인 화면으로 돌아간다.
- 스캔 화면 오른쪽 위 로그아웃 버튼은 확인 팝업을 한 번 띄운다(손전등 버튼 옆이라 오터치 방지).

## 구조

```
lib/
├── main.dart                        # 기기 저장소에서 세션 되살리기
├── app.dart                         # API 구현 선택 + 인터셉터 + 로그인 여부로 첫 화면 선택
├── core/
│   ├── network/                     # ApiClient(dio) · ApiException · AuthInterceptor — 팬 앱과 같은 규약
│   ├── theme/                       # AppColors · AppTheme
│   └── widgets/                     # showErrorSnackBar
├── features/auth/                   # 팬 앱 features/auth 에서 로그인·로그아웃·재발급만 가져옴
│   ├── constants.dart               # 문구 · 오류 코드 · 역할 이름
│   ├── models/                      # AuthTokens · ReissuedAccessToken · AccessTokenClaims(roles 판정)
│   ├── data/                        # AuthApi · HttpAuthApi · MockAuthApi · TokenStorage · DeviceId
│   ├── state/                       # AuthSession(로그인 상태) · AuthSessionScope · AuthApiScope
│   ├── screens/login_screen.dart
│   └── widgets/                     # AuthPage · LabeledTextField · ObscureToggle · LogoutButton
└── features/scan/
    ├── constants.dart               # 시간·치수·문구. 매직 넘버는 전부 여기
    ├── models/                      # GateTarget · VerificationResult(Admitted/Rejected/Undetermined) · RejectReason
    ├── data/                        # ScanApi(인터페이스) · HttpScanApi · MockScanApi
    ├── state/scan_api_scope.dart    # ScanApi 를 화면에 내려주는 InheritedWidget
    ├── screens/scan_screen.dart     # 카메라 · 중복 인식 차단 · 결과 표시 · 로그아웃 버튼
    └── widgets/                     # ScanViewfinder(조준 틀) · ScanResultView(결과 전체 화면)
```

## 서버 규약

- 검표 응답은 **거절도 4xx 가 아니라 200** 이다 — `{ admitted: false, reasonCode: "EXPIRED" }`.
  화면이 상태 코드를 해석하지 않고 `admitted` 만 보게 하려는 것이고, 덕분에 4xx/5xx 는 전부
  "판정 실패(확인 실패 화면)" 하나로 다룬다(`scan_api.dart` 주석).
- `RejectReason.code` 는 백엔드 `GateRejectReason` 열거형 이름과 같아야 한다. 모르는 코드는
  `unknown` 으로 떨어져 중립 문구가 나온다.
- 팬 앱의 QR 이 서버 서명 토큰으로 바뀌면 `EntryPayload` 상수와 `MockScanApi` 의 파싱은
  지운다. 앱은 페이로드를 해석하지 않고 그대로 보낸다 — `HttpScanApi` 는 이미 그렇다.

## 규칙

팬 앱 README 의 네이밍·테마 규칙과 팀 CONVENTION.md 를 그대로 따른다.
색은 `AppColors` 만 쓴다. 결과 3종은 색 + 아이콘 + 문구를 항상 함께 바꾼다.
