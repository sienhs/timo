import 'package:flutter/material.dart';

import '../features/home/screens/home_screen.dart';

/// 화면 라우트 등록부.
/// 새 화면을 만들면 1) 이름 상수 추가, 2) routes 맵에 builder 등록.
/// 이동은 Navigator.pushNamed(context, AppRoutes.xxx) 사용.
class AppRoutes {
  AppRoutes._();

  static const home = '/';

  static final Map<String, WidgetBuilder> routes = {
    home: (_) => const HomeScreen(),
  };
}
