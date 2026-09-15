# Frontend (Flutter)

## 실행

```bash
flutter pub get
flutter run -d chrome   # 웹으로 실행. 기기 목록은 flutter devices
```

## 폴더 구조

```
lib/
├── main.dart                 # 앱 실행 진입점 (runApp만)
├── app.dart                  # MaterialApp: 테마·라우트 연결
├── core/
│   └── theme/app_theme.dart  # 공통 테마 (색상 등 디자인 토큰)
├── routes/
│   └── app_routes.dart       # 라우트 이름 상수 + 화면 등록부
├── common/
│   └── widgets/              # 여러 기능에서 같이 쓰는 공용 위젯
└── features/                 # 기능 단위 폴더 (기능별로 담당자가 작업)
    └── home/
        └── screens/home_screen.dart
```

## 새 기능 작업 방법

1. `features/` 아래에 기능 폴더를 만든다 (예: `features/seat/`).
2. 그 안에 `screens/`, `widgets/`, `models/`, `data/` 등 필요한 것만 만든다.
3. 화면이 생기면 `routes/app_routes.dart`에 이름 상수와 builder를 등록한다.
4. 화면 이동은 `Navigator.pushNamed(context, AppRoutes.xxx)`를 쓴다.

## 규칙

- 네이밍은 Dart 공식 컨벤션을 따른다 (린터가 검사함):
  - 변수·함수·상수: lowerCamelCase (`maxSelectable`)
  - 클래스·enum: UpperCamelCase (`SeatSelectionScreen`)
  - 파일·폴더 이름: snake_case (`seat_selection_screen.dart`)
- 색상·테마 값은 위젯에 하드코딩하지 말고 `AppTheme`/`Theme.of(context)`에서 가져온다.
- 두 개 이상의 기능에서 쓰는 위젯만 `common/widgets/`로 올린다.

## 서버 주소

앱은 기본으로 **내 컴퓨터에서 띄운 백엔드**에 붙는다. 안드로이드 에뮬레이터에서 호스트 컴퓨터는 `10.0.2.2` 로 보이므로 기본 주소가 `http://10.0.2.2:8080` 이다 (`lib/core/network/api_client.dart`).

다른 서버에 붙일 때는 실행 인자로 바꾼다.

```bash
# 배포 서버
flutter run --dart-define=API_BASE_URL=https://api.ticketmoa.site

# 실제 폰으로 내 컴퓨터의 백엔드에 붙을 때 (같은 와이파이, 컴퓨터 IP 로)
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080
```

- 기본 주소가 암호화 없는 http 라서 디버그 빌드의 안드로이드 설정(`android/app/src/debug/AndroidManifest.xml`)에서만 http 를 허용해 두었다. 배포 빌드는 https 만 된다.
- 백엔드를 내 컴퓨터에서 띄우려면 Docker Desktop 을 켜고 `backend/timo` 에서 `./gradlew bootRun`. 자바 21 이 필요하다. 로컬 프로필에서는 인증 문자가 실제로 가지 않고 백엔드 콘솔에 `[SMS NOT SENT] … code=…` 로 인증번호가 찍힌다.
- 배포 서버는 인증 문자가 실제로 가고, 한 번 가입한 전화번호로는 다시 가입할 수 없다.

## 내 티켓 화면 (가짜 데이터로 띄우기)

내 티켓 화면(`features/ticket/`)은 기본으로 백엔드 v0 스텁에 붙는다. 그런데 **스텁으로는 화면을 채울 수 없다.** 주문하려면 공연이 `ON_SALE` 이어야 하는데 고정 공연 4개 중 하나뿐이고 1인 1매라, 만들 수 있는 티켓이 한 장이다. 지난 공연은 아예 못 만든다.

그래서 화면을 눈으로 볼 때는 앱 안의 가짜 데이터를 쓴다. 백엔드가 없어도 된다.

```bash
flutter run --dart-define=TICKET_API=mock          # 시안 그대로 (예정 2 · 지난 2)
flutter run --dart-define=TICKET_API=mock-states   # 발행 중 · 발행 실패 · 환불됨 · 취소됨
flutter run --dart-define=TICKET_API=mock-empty    # 두 탭 모두 빈 목록
flutter run --dart-define=TICKET_API=mock-error    # 에러 화면 + 다시 시도
flutter run                                         # 기본값. 실제 서버(v0 스텁)
```

- 가짜 데이터의 날짜는 **실행 시각 기준 상대값**이다(`data/mock_ticket_api.dart`). 시안 날짜를 그대로 박으면 그날이 지나는 순간 예정 공연이 전부 지난 공연 탭으로 넘어간다.
- 실제 서버로 확인할 때는 `backend/timo/http/stub/my-tickets-seed.http` 로 티켓을 만들어 넣는다. 무엇이 되고 안 되는지 그 파일 맨 위에 적어 뒀다.

### 입장 QR

**서버 API 가 아직 없다.** QR 문자열(`timo:entry:{예매id}:{발급시각}:{난수}`)을 앱이 만들어 30초마다 새로 그린다(`models/entry_pass.dart`).

실제로는 **서버가 서명한 토큰**이어야 한다. 지금 값은 규칙만 알면 누구나 똑같이 만들 수 있어 위조를 막지 못하고, 검표기가 발급 시각을 확인할 방법도 없어 30초 회전은 모양만 흉내 낸 것이다. 티켓 도메인이 생기면 `EntryPass.issue` 를 "서버에서 받아오기" 로 바꾸면 된다 — 화면은 그대로다.

- 남은 시간은 타이머가 몇 번 울렸는지가 아니라 **시계로 잰다.** 앱이 백그라운드로 가면 타이머가 멈추는데, 횟수로 세면 10분 지난 QR 을 "25초 남음" 으로 보여주게 된다.
- 화면 밝기를 올리거나 화면이 꺼지지 않게 하는 처리는 아직 없다. 어두운 폰으로는 리더기가 QR 을 못 읽을 수 있어, 실제 입장 검증을 붙일 때 같이 넣는다.
- 화면 캡처는 막지 않는다(`FLAG_SECURE` 미적용). 시안 문구도 "캡처한 QR 은 입장할 수 없다" 이지 "캡처할 수 없다" 가 아니다.
- 시안의 `입장 게이트: GATE1` 은 뺐다. 예매 응답에 그 값이 없고, 없는 정보를 채우면 실제 게이트와 다를 때 입장에서 문제가 된다.

**NFT 소장품**도 서버가 없다. 지난 공연 카드의 버튼은 누르면 안내만 띄운다.

### 양도 목록 탭은 뺐다

시안에는 `양도 목록` 탭이 하나 더 있다. 양도 **등록** 진입점이 이번 범위에 없어 늘 비어 있는 데다, 마켓 API 가 S15P21D206-297 에서 새로 설계되면서 붙여 둔 연동이 맞지 않게 됐다 — 매물 식별자가 `tokenId` 에서 `listingId` 로 바뀌고(온체인 공개값인 `tokenId` 를 내보내면 소유 이력이 역추적된다), 목록이 `GET /market/listings/me` 하나로 합쳐졌으며, 응답에서 좌석 번호가 빠졌다.

양도 작업을 할 때 새 규약으로 함께 되살린다. 카드 디자인(`ListingCard`)은 커밋 `ebf3bea` 까지의 히스토리에 있다.

## 로그인 상태

- 로그인·가입에 성공하면 받은 토큰을 `AuthSession`(`features/auth/state/`)에 담고 기기 보안 저장소(flutter_secure_storage)에 저장한다. 앱을 켤 때 `main.dart` 가 되살리므로 다시 켜도 로그인 상태가 유지된다.
- 화면에서 로그인 여부가 필요하면 `AuthSessionScope.of(context).isLoggedIn` 을 읽는다.
- 로그아웃은 두 단계다. `signOut()` 으로 기기 토큰을 지우고(화면이 바로 바뀐다), 이어서 `AuthApi.logout(refreshToken)` 으로 서버 세션을 끊는다. 리프레시 토큰은 `signOut()` 전에 꺼내 둬야 한다. 서버에 못 알려도(네트워크 끊김) 로그아웃은 된 것으로 친다. 마이페이지 버튼(`features/mypage/`)이 예시다.
- 로그인 상태면 모든 서버 요청에 `Authorization: Bearer …` 가 자동으로 붙는다(`core/network/auth_interceptor.dart`). 인증 주소(`/api/v1/auth/…`)는 예외 — 만료된 토큰이 붙으면 로그인·재발급 자체가 401 로 막히기 때문이다.
- **액세스 토큰이 만료되면 자동으로 재발급받아 요청을 이어간다.** 서버가 401 을 주면 인터셉터가 리프레시 토큰으로 새 액세스 토큰을 받고, 실패했던 요청을 다시 보내 그 응답을 화면에 돌려준다. 화면은 만료가 있었는지 모른다. 코드는 `core/network/auth_interceptor.dart`, 실제 재발급 조립은 `app.dart` 에 있다.
  - 응답의 `errorCode` 가 `TOKEN_INVALID`·`REFRESH_REUSED` 면 재발급해도 소용없으므로 바로 로그아웃한다. **이 구분이 없으면 무한 재발급 루프가 된다.**
  - 재발급까지 실패하면 로그아웃 상태가 된다.
  - 동시에 여러 요청이 만료로 막혀도 재발급은 한 번만 나가고, 나머지는 그 결과를 같이 받는다.
  - 만료 직전에 미리 받아 두는 방식은 아직 없다. 필요해지면 얹는다.
