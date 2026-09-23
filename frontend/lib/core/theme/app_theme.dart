import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_metrics.dart';

/// 앱 공통 테마. 색은 [AppColors], 크기·굵기는 여기서만 정의한다. 화면에서는
/// `Theme.of(context).textTheme.xxx` 로 가져다 쓴다.
class AppTheme {
  AppTheme._();

  /// 브랜드 메인 색. [AppColors.brand] 와 같은 값이며 [dark] 의 시드로 쓴다.
  static const seedColor = AppColors.brand;

  /// 시안 폰트는 Pretendard 계열로 보인다. 폰트 파일을 assets 에 넣고
  /// pubspec 에 등록한 뒤 여기에 'Pretendard' 를 지정하면 전체가 바뀐다.
  static const String? _fontFamily = null;

  static const _scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    error: AppColors.error,
    onError: Colors.white,
    surfaceContainerHighest: AppColors.surfaceMuted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );

  /// 폰트를 입히기 전의 정의. 직접 쓰지 말고 [_textTheme] 를 쓴다.
  static const _baseTextTheme = TextTheme(
    // '결제가 완료됐어요' 같은 화면 대표 문구
    headlineSmall: TextStyle(
      fontSize: 20,
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
    // 좌석명·금액 등 값 강조
    titleSmall: TextStyle(
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.5,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
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
      color: AppColors.textPrimary,
    ),
    // 필드 라벨('선택한 좌석', '결제 금액'), 범례
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.3,
      color: AppColors.textSecondary,
    ),
    // '* 1인 1매만 예매할 수 있어요'
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.4,
      color: AppColors.textSecondary,
    ),
  );

  /// 브랜드 강조 색. [AppColors.accent] 와 같다. 참조하는 코드가 있어 남긴다.
  static const accentColor = AppColors.accent;

  /// 폰트를 입힌 최종 텍스트 테마. ThemeData(fontFamily:) 는 컴포넌트 테마에 직접
  /// 넣은 TextStyle(버튼·AppBar 제목)에는 안 먹으므로 그쪽도 반드시 이 값을 쓴다.
  static final _textTheme = _baseTextTheme.apply(fontFamily: _fontFamily);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    colorScheme: _scheme,
    textTheme: _textTheme,
    scaffoldBackgroundColor: AppColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: _textTheme.titleMedium,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: 0,
    ),
    // 입력칸 공통 모양. Material 3 는 border 하나만 주면 포커스·오류 상태 색이
    // 따라오지 않으므로 상태별 테두리를 전부 명시한다.
    inputDecorationTheme: InputDecorationThemeData(
      isDense: true,
      // 글자를 bodyMedium(14 × 1.5 = 21) 으로 두면 칸 높이가
      // 13.5 × 2 + 21 = 48 이 되어 옆에 붙는 버튼 높이와 딱 맞는다.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13.5,
      ),
      hintStyle: _textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
      ),
      helperStyle: _textTheme.labelMedium,
      errorStyle: _textTheme.labelMedium?.copyWith(color: AppColors.error),
      border: _inputBorder(AppColors.border),
      enabledBorder: _inputBorder(AppColors.border),
      focusedBorder: _inputBorder(AppColors.primary, width: 1.5),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error, width: 1.5),
      disabledBorder: _inputBorder(AppColors.textDisabled),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textSecondary,
        minimumSize: const Size.fromHeight(AppMetrics.buttonMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: _textTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppMetrics.controlRadius),
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        disabledForegroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size.fromHeight(AppMetrics.buttonMinHeight),
        textStyle: _textTheme.labelLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppMetrics.controlRadius),
          ),
        ),
      ),
    ),
    // 다이얼로그의 얇은 그린 테두리는 shape.side 로 안 그려져 위젯이 직접 그린다.
    // 여기서는 모양만 잡는다.
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: _textTheme.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );

  /// 입력칸 테두리. 색과 굵기만 다르고 모서리는 버튼과 같은 12 이다.
  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(AppMetrics.controlRadius),
        ),
        borderSide: BorderSide(color: color, width: width),
      );

  /// 다크 테마 시안은 아직 없어 시드 기반 기본 구현만 남긴다. [light] 와 짝이
  /// 맞지 않으므로 시안이 나오면 [AppColors] 에 다크 토큰을 추가해 조립한다.
  static ThemeData get dark => ThemeData(
    colorSchemeSeed: seedColor,
    brightness: Brightness.dark,
    useMaterial3: true,
  );
}
