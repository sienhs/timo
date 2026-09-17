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
    ├── splash/               # 앱 첫 화면(로딩). 끝나면 홈으로 넘어간다
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

## 로딩 화면

앱은 로딩 화면(`features/splash/`)에서 시작한다. 시안 '로딩 1~4' 대로 `세상의 모든 티켓을 모아,` 아래 워드마크가 `ticket moa → TIcket MOa → TIMO` 로 바뀌고 마지막에 로고가 뜬다. 2.5초 뒤 홈으로 **교체** 이동해 뒤로 가기로 돌아올 수 없다. 장면별 시간은 `features/splash/constants.dart` 한 곳에서 고친다.

- **서버를 부르지 않는다.** 로그인 되살리기는 `main.dart` 가 앱을 띄우기 전에 끝내고, 홈 데이터는 홈이 스켈레톤을 보이며 직접 받는다. 버전 확인·점검 공지 API 가 생기면 그때 이 화면에 붙인다.
- 첫 화면은 `App(initialRoute:)` 로 바꿀 수 있다. 앱을 통째로 띄우는 테스트는 `AppRoutes.home` 을 넘겨 로딩을 건너뛴다. 첫 화면 이름이 `/` 아래에 있으면 Flutter 가 홈을 먼저 쌓아 버리는 함정이 있어, `app.dart` 가 첫 화면을 하나만 쌓도록 직접 만든다.
- Flutter 가 뜨기 전 안드로이드가 보여 주는 런치 화면(`android/app/src/main/res/drawable*/launch_background.xml`)은 흰 배경만 있다. 로딩 화면 배경과 같은 색이라 이어져 보인다.

## 내 티켓 화면

내 티켓 화면(`features/ticket/`)은 기본으로 v1 예매 API(`/api/v1/reservations`)에 붙는다. **로그인이 필요하다** — 서버가 요청한 회원의 주문만 준다. 로컬 백엔드는 시더가 시드 계정(`seed001` 등, 비밀번호는 백엔드 시작 로그에 찍힌다)에 예매를 넣어 두므로 그 계정으로 로그인하면 카드가 바로 보인다.

서버로 만들 수 없는 화면만 앱 안의 가짜 데이터로 본다. 백엔드가 없어도 된다.

```bash
flutter run --dart-define=TICKET_API=mock          # 시안 그대로 (예정 2 · 지난 2)
flutter run --dart-define=TICKET_API=mock-states   # 예매 취소됨 · 앱이 모르는 상태
flutter run --dart-define=TICKET_API=mock-empty    # 두 탭 모두 빈 목록
flutter run --dart-define=TICKET_API=mock-error    # 에러 화면 + 다시 시도
flutter run                                         # 기본값. 실제 서버(v1)
```

- 가짜 데이터의 날짜는 **실행 시각 기준 상대값**이다(`data/mock_ticket_api.dart`). 시안 날짜를 그대로 박으면 그날이 지나는 순간 예정 공연이 전부 지난 공연 탭으로 넘어간다.

### 티켓 상태는 결제됨 · 취소됨 둘뿐이다

서버의 주문 상태(`ReservationStatus`)가 `PAID` · `CANCELLED` 두 가지다. **온체인 발행이 어디까지 갔는지는 주문이 아니라 티켓 쪽 관심사**라 서버가 주문 상태에서 뺐다(S15P21D206-298).

그래서 앱도 `models/ticket_status.dart` 를 그 둘에 맞췄고, 발행 중 · 발행 실패 · 환불됨 카드는 걷어냈다. 서버가 그 값을 주지 않으니 남겨 두면 영원히 그려지지 않는 화면이 된다. 티켓 도메인이 생기면 되살린다 — 카드와 배지는 커밋 `0062a8e` 까지의 히스토리에 있다.

모르는 값이 오면 **'알 수 없음'** 으로 받아 그 카드만 잠그고 "지금은 이용할 수 없어요" 를 띄운다. 목록 전체를 예외로 깨뜨리지 않으면서, 취소되지 않은 티켓에 "예매를 취소했어요" 를 붙이는 거짓말도 하지 않기 위해서다. `mock-states` 로 그 카드를 볼 수 있다.

결제 완료 화면의 발행 배지는 주문 상태가 아니라 **주문 상세의 `tokenId` · `failureReason`** 으로 바꾼다(아래 '결제와 주문' 참고). 목록 응답에는 그 값이 없어 내 티켓 카드는 그대로 결제됨 · 취소됨 둘뿐이다.

### 입장 QR

예정 공연 카드의 `입장 QR 보기` 는 **서버가 발급한 QR**(`GET /api/v1/tickets/{ticketId}/entry-pass`, S15P21D206-324)을 그린다(`screens/entry_qr_screen.dart`). 응답은 QR 에 실을 문자열과 남은 수명(초) 둘이다. 앱은 문자열 안을 **해석하지 않고** 그대로 그린다 — 해석을 시작하면 서버가 형식을 바꿀 때마다 앱 배포가 묶인다. 남은 시간도 토큰이 아니라 함께 온 초 값으로 센다(`models/entry_pass.dart`). 빠른 메뉴의 `입장QR` 도 내 티켓으로 보낸다 — QR 은 티켓 한 장에 붙는 것이라 따로 화면이 없다.

- 버튼은 **공연 시작 2시간 전부터 6시간 뒤까지** 열린다(`TicketMetrics.qrOpensBefore` · `qrClosesAfter`). 백엔드 `EntryPassService` 의 창과 같아야 한다 — 앱이 더 일찍 열면 버튼은 눌리는데 서버가 409 로 거절한다. 안 열린 카드의 한 줄 문구도 이 상수에서 시각을 가져온다.
- 수명(기본 30초)이 다하면 **자동으로 새로 받지 않는다.** QR 을 흐리게 하고 가운데 새로고침 버튼을 두어, 누르면 새로 받는다. 줄을 서는 동안 30초마다 요청이 나가거나 검표 직전에 QR 이 바뀌는 일이 없다. 남은 시간이 5초 안쪽이면 카운트다운이 경고색으로 바뀐다(`widgets/qr_countdown_bar.dart`).
- 남은 시간은 타이머가 몇 번 울렸는지가 아니라 **응답을 받은 시각부터 시계로 잰다.** 앱이 백그라운드로 가면 타이머가 멈추는데, 횟수로 세면 10분 지난 QR 을 "25초 남음" 으로 보여주게 된다. 서버가 주는 것이 만료 시각이 아니라 남은 초라, 기기 시계와 서버 시계가 어긋나도 상관없다.
- 실패하면 QR 자리에 **서버 문구 그대로**와 다시 시도가 뜬다. 남의 티켓·없는 티켓은 404, 발행 전·이미 입장·회수·양도 등록 중·입장 시간대 밖은 409 다. 예매 목록에 티켓 상태가 없어 양도 등록 중인 티켓도 버튼이 열리는데, 그때는 서버가 409 로 막고 그 문구가 여기 뜬다.
- 화면 밝기를 올리거나 화면이 꺼지지 않게 하는 처리는 아직 없다. 패키지 두 개(밝기 · 화면 유지)가 새로 들어가야 해서 별도 이슈로 뺐다.
- 화면 캡처는 막지 않는다(`FLAG_SECURE` 미적용). 시안 문구도 "캡처한 QR 은 입장할 수 없다" 이지 "캡처할 수 없다" 가 아니다.
- 시안의 `입장 게이트: GATE1` 은 뺐다. 예매 응답에 그 값이 없고, 없는 정보를 채우면 실제 게이트와 다를 때 입장에서 문제가 된다.
- 가짜 API(`TICKET_API=mock`)도 QR 을 내준다. 서버 형식과 글자 수만 같은 가짜 문자열이라 검표기에는 통하지 않는다.
- **로컬 실서버로 보려면** 시드 공연이 입장 창 안이어야 한다. 시드 공연 날짜는 고정이라(로이킴 2026-09-20 19:30 등) 그 밖의 날은 `backend/timo/http/domain/ticket/entry-pass-fixture.sql` 로 공연 시각을 당긴다. 에뮬레이터 타임존이 GMT 면 앱이 공연 시각을 9시간 늦게 읽어 버튼이 안 열린다 — `adb shell cmd alarm set-timezone Asia/Seoul` 로 맞춘다(루트 없이 된다).

**NFT 소장품**도 서버가 없다. 지난 공연 카드의 버튼은 누르면 안내만 띄운다.

### 양도 목록 탭은 마켓 API 를 본다

세 번째 탭 `양도 목록` 은 예매 목록이 아니라 **양도마켓 API 의 내 거래 내역**(`GET /api/v1/market/listings/me`)에서 내가 올린 매물만 골라 그린다(`features/resale/models/my_trade.dart`). 서버는 판매·구매를 한 목록으로 주지만 이 탭은 **판매만** 보여 준다 — 시안이 그렇고, 양도로 산 티켓은 "내 티켓" 이라 예정 공연 탭에 나와야 맞다.

- 예매 목록과 **따로 받는다.** 마켓이 실패해도 예정·지난 탭은 보이고, 양도 탭만 다시 시도를 낸다. 탭 옆 숫자는 판매중인 매물만 센다.
- 카드(`widgets/listing_card.dart`)는 판매중(배지 · 등록가 · 마감 · `가격 수정` · `등록 취소`), 판매 완료, 등록 취소 세 모양이다. 팔린 것과 내린 것도 회색 카드로 남긴다 — 예매 취소 카드와 같은 판단이다. 등록가 단위는 다른 결제 금액과 같이 MSR.
- `등록 취소` 는 확인 팝업 → `POST /market/listings/{id}/cancel` → 목록 재조회다. 팝업 틀(`widgets/ticket_confirm_dialog.dart`)은 예매 취소와 같은 것을 쓴다.
- `가격 수정` 은 바텀시트(`features/resale/widgets/listing_price_sheet.dart`) → `PATCH /market/listings/{id}/price` → 목록 재조회다. 판매가 입력 자리와 상한 규칙(등록 시점 정가 이하)은 등록 화면과 같은 것을 쓴다. 같은 값으로는 보낼 수 없고, 바꾸면 "등록가를 바꿨어요" 한 줄을 띄운다.
- 예정 공연 카드 더보기(⋮)의 `양도 등록하기` 가 그 티켓의 `ticketId` 를 얹어 양도마켓 등록 화면으로 보낸다. 등록 화면은 그 티켓을 골라 둔 채 가격 단계로 열린다(목록에 없으면 고르기부터). 등록하고 돌아오면 목록을 다시 받는다.
- 마켓 API 는 다른 도메인과 같이 **실서버(v1)가 기본**이다. 시안 데이터로 보려면 `--dart-define=RESALE_API=mock`(`features/resale/` 참고). 목의 내 거래 내역은 판매중 하나 · 팔린 것 하나다.

예매 응답의 `ticketId` 는 예매 번호(`id`)와 **다른 값**이다. 양도 등록이 받는 것은 `ticketId` 라 바꿔 쓰면 서버가 거절한다(S15P21D206-323 에서 응답에 실렸다).

**서버가 아직 못 주는 것**(S15P21D206-308 에서 백엔드에 전달): 예매 응답에 "양도 등록 중" 표시가 없어 등록한 티켓도 예정 공연 탭에서 입장·취소가 되는 것처럼 보이고, 양도로 산 티켓은 구매자의 예매 목록에 나오지 않는다.

## 결제와 주문

결제 화면(`features/payment/`)의 `결제하기` 는 서버에 주문을 만든다(`POST /api/v1/reservations`, 공연 번호 + 좌석 번호). 결제 수단을 고르는 단계는 없다 — 결제는 예치 잔액(버섯) 차감 한 가지뿐이라 서버가 이 요청 안에서 좌석 배정과 차감을 끝낸다. 주문 API 는 내 티켓과 같은 `TicketApi`(`features/ticket/data/`)에 있다.

- **예매 수수료는 없다.** 시안의 `예매 수수료 3,000원` 줄은 뺐다. 서버는 구역 정가만 차감하고 환불도 정가 전액이라, 수수료를 더해 보여 주면 찍히는 금액과 실제 빠지는 금액이 어긋난다(S15P21D206-176 결정). 결제 화면 · 완료 화면 · 좌석 선택 하단 바가 모두 구역 정가 하나를 찍는다.
- 결제 화면은 **잡아 둔 자리가 있을 때만** 서버를 부른다. 예매 흐름 밖에서 열리면(디자인 확인 · 화면 단위 테스트) 완료 화면만 보여 준다.
- 서버가 거절하면(선점 만료 · 남의 선점 · 이미 산 공연 · 판매 중 아님 · 로그인 풀림, 4xx) 사유를 띄우고 좌석 화면으로 돌아간다. 좌석 화면이 잡아 둔 자리를 정리하고 배치도를 새로 받는다. 인터넷 끊김과 서버 오류(5xx)는 결제 화면에 남아 다시 누를 수 있다.
- 주문이 만들어지면 결제 화면은 완료 화면으로 **교체**되고 좌석 화면에 `true` 를 남긴다. 좌석 화면은 그 값을 보고 선점을 **풀지 않는다** — 서버가 선점을 주문으로 바꿨기 때문이다. 결제 없이 돌아오면 전처럼 푼다.

### 완료 화면은 발행이 끝나기를 기다린다

주문이 만들어진 순간 티켓은 아직 체인에 올라가는 중이다(서버가 잔액을 차감하고 NFT 를 발행한다). 완료 화면은 3초마다 주문 상세(`GET /api/v1/reservations/{id}`)를 물어 배지를 바꾼다(`features/ticket/models/reservation_detail.dart` 의 `issueStatus`).

| 서버 응답 | 배지 |
| --- | --- |
| `tokenId` 없음 · `failureReason` 없음 | 티켓 발행 중 (시안) |
| `tokenId` 채워짐 | 티켓 발행 완료 |
| `failureReason` 채워짐, 또는 주문이 `CANCELLED` | 티켓 발행 실패 · "결제된 금액은 자동으로 환불돼요" |

- 2분이 지나도 안 끝나면 그만 묻고 "발행 중" 으로 둔다. 결과는 내 티켓에서 확인하면 된다.
- 한 번 못 물은 것(인터넷 끊김)은 실패로 그리지 않고 다음 주기에 다시 묻는다.
- `티켓 보러 가기` 는 결제 흐름 화면을 다 닫고 홈 위에 내 티켓을 올린다.
- 가짜 API(`TICKET_API=mock`)도 주문을 만든다. 상세를 두 번 물으면 발행이 끝나고, `mock-states` 에서는 실패로 끝난다 — 서버로는 만들기 어려운 실패 화면을 보는 방법이다.

### 로컬에서 실제로 결제해 보려면

- **시드 계정(`seed001` 등)으로는 끝까지 안 간다.** 시더가 지갑을 주최자에게만 만들어서, 시드 계정은 지갑 조회가 500 이고 결제하면 서버의 정산이 지갑 조회에서 멈춰 티켓이 "발행 중" 으로 영영 남는다(그 공연은 그 계정으로 다시 예매도 못 한다). **직접 가입한 계정**으로 한다. 가입 인증 코드는 백엔드 콘솔 로그에 찍힌다.
- 잔액이 구역 정가(A·B 15만, C·D 12만, 2층 E 9.9만)보다 적으면 서버가 차감 실패로 주문을 되돌리고 화면은 "발행 실패" 가 된다. 마이페이지 충전에서 먼저 채운다.
- 시드로 넣은 예매 220건은 티켓 행이 없어 상세 조회가 500 이다. 앱이 새로 만든 주문은 티켓이 같이 생겨 폴링이 된다. 둘 다 백엔드 쪽 일이다.

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

## 메모리 티켓(소장품)

빠른 메뉴 → **컬렉션**. 공연 사진을 골라 기기 안에서 인물을 떼어내고 깊이를 추론해
입체 티켓으로 만든다. 만든 소장품은 서버가 아니라 기기(Hive)에 남는다.

### 받은 뒤 한 번만

추론 모델(약 60MB)이 **Git LFS** 로 들어 있다. LFS 없이 클론하면 `.onnx` 자리에
포인터 텍스트만 받아져 빌드는 되지만 실행 중에 모델 로드가 실패한다.

```bash
git lfs install
git lfs pull
```

### 실행

```bash
flutter run
```

추억 티켓 제작은 전부 기기 안에서 돈다(누끼·깊이·합성). 외부 생성형 AI 호출이나
API 키 주입은 없다.

### 알아둘 것

- **minSdk 24.** ML Kit 셀피 분할과 ONNX Runtime 의 하한이다.
- **APK 가 커진다.** 모델 60MB + ONNX Runtime 네이티브 라이브러리가 들어간다.
  배포용은 반드시 **`flutter build apk --release --split-per-abi`** 로 뽑는다
  (arm64 약 129MB). `--target-platform android-arm64` 만으로는 ONNX·MediaPipe·
  ML Kit 이 3개 ABI 를 다 싣기 때문에 215MB 가 된다.
- **릴리스는 R8 을 탄다.** `android/app/proguard-rules.pro` 가 ML Kit·MediaPipe·
  ONNX Runtime 의 리플렉션/JNI 진입점과 flogger 를 지켜 준다. 이 규칙이 없으면
  빌드가 아예 안 되거나, 되더라도 실행 중 포즈 추정에서 프로세스가 죽는다.
- **모델은 Flutter 에셋이 아니다.** 네이티브(`DepthProcessor`·`PortraitMatting`)가
  AssetManager 로 직접 여는 Android 에셋이라, `android/app/build.gradle.kts` 의
  sync 태스크가 빌드 때 복사한다. pubspec 에 또 올리면 APK 에 두 번 들어간다.
- **FP32 깊이 모델(95MB)은 레포에 없다.** 배포에는 INT8 만 싣는다. 다시 양자화할
  일이 있으면 `tools/download_depth.py` → `tools/export_depth.py` →
  `tools/quantize_depth.py` 순서로 로컬에 만든다.

### 폴더

```
lib/features/memory/
├── constants.dart      # 문구·치수·처리 상수 (영역별 클래스)
├── data/               # 네이티브 채널(timo/image_pipeline)·저장소·공연 API
├── models/             # 소장품·공연·효과·프레이밍
├── state/              # TicketStore / CreationJob / 공연 API 스코프
├── screens/            # 컬렉션·제작·뷰어
├── widgets/            # collection · creator · viewer · ui
├── effects/            # 셰이더 패스·블룸·볼류메트릭
├── motion/             # 앰비언트 모션·전환 토큰
└── theme/              # 소장품 전용 팔레트와 어두운 무대 테마
```

모델을 왜 이걸 골랐는지, 인물 깊이 레이어와 빛줄기를 어떻게 만드는지는
`docs/memory/` 에 있다.
