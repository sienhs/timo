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
