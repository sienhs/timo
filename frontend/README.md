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
