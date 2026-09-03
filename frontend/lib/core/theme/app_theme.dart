import 'package:flutter/material.dart';

/// 앱 공통 테마. 색상·폰트 등 디자인 토큰은 여기서만 정의한다.
class AppTheme {
  AppTheme._();

  static const seedColor = Color(0xFF149F5C);

  static ThemeData get light => ThemeData(
        colorSchemeSeed: seedColor,
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      );
}
