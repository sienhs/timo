import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 공통 테마. 색은 [AppColors], 크기·굵기는 여기서만 정의한다.
///
/// 화면 코드에서는 `Theme.of(context).textTheme.xxx` 로 가져다 쓴다.
/// 게이트 운영자는 서서, 밝은 곳에서, 급하게 본다. 팬 앱보다 글자를 한 단계
/// 크게 잡았다.
class AppTheme {
  AppTheme._();

  static const _scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.rejected,
  );

  static const _textTheme = TextTheme(
    // 결과 배너의 "입장" / "입장 불가"
    displaySmall: TextStyle(
      fontSize: 40,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
    // 화면 대표 문구
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    // AppBar 제목
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    // 카드 제목·값 강조
    titleSmall: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    // 안내 문단
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.6,
      color: AppColors.textSecondary,
    ),
    // 버튼
    labelLarge: TextStyle(
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
    // 필드 라벨
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.3,
      color: AppColors.textSecondary,
    ),
  );

  static const buttonHeight = 52.0;
  static const fieldRadius = 10.0;

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: _scheme,
    textTheme: _textTheme,
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.textDisabled,
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
        textStyle: _textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
        textStyle: _textTheme.labelLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: AppColors.rejected),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(fieldRadius),
        borderSide: const BorderSide(color: AppColors.rejected, width: 1.5),
      ),
      labelStyle: _textTheme.labelMedium,
      hintStyle: _textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
    ),
  );
}
