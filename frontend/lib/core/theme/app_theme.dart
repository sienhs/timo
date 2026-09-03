import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 공통 테마. 색은 [AppColors], 크기·굵기는 여기서만 정의한다.
///
/// 화면 코드에서는 `Theme.of(context).textTheme.xxx` 로 가져다 쓴다.
/// TextStyle 을 위젯마다 새로 만들면 시안이 바뀔 때 전수 수정해야 하고
/// 스타일 객체도 매 빌드마다 새로 생성된다.
class AppTheme {
  AppTheme._();

  /// 브랜드 메인 색(S15P21D206-49). Material 3 팔레트를 생성하는 시드로 쓴다.
  /// 값은 [AppColors.brand] 로 옮겼고, 이 이름을 참조하는 코드가 있어 유지한다.
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
      color: Colors.white,
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

  /// 브랜드 강조 색. 금액·경고처럼 시선을 끌어야 하는 곳에 쓴다.
  /// 값은 [AppColors.accent] 로 옮겼고, 이 이름을 참조하는 코드가 있어 유지한다.
  static const accentColor = AppColors.accent;

  /// 폰트를 입힌 최종 텍스트 테마.
  ///
  /// ThemeData(fontFamily:) 는 textTheme 에만 폰트를 입히고, 컴포넌트 테마에
  /// 직접 넣은 TextStyle(버튼 textStyle, AppBar titleTextStyle 등)에는 적용되지
  /// 않는다. 그래서 그쪽도 반드시 이 값을 참조해야 한다. 골든 스크린샷에서
  /// AppBar 제목과 버튼 라벨만 폰트가 안 먹는 것으로 이 문제가 드러났다.
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
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textDisabled,
            minimumSize: const Size.fromHeight(52),
            textStyle: _textTheme.labelLarge,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            minimumSize: const Size.fromHeight(46),
            textStyle: _textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
            ),
          ),
        ),
        // 시안의 다이얼로그는 얇은 그린 테두리를 가지는데, shape.side 로는
        // Material 이 테두리를 그려주지 않는다. 테두리는 다이얼로그 위젯이
        // 직접 그리므로 여기서는 모양만 잡는다.
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
          contentTextStyle: _textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );

  /// 다크 테마 시안은 아직 없다. develop 에 있던 시드 기반 구현을 그대로
  /// 남겨둔다(참조하는 코드가 있을 수 있어 API 를 없애지 않는다).
  ///
  /// 다만 [light] 는 흰 배경·회색 테두리를 명시적으로 지정하므로 이 다크
  /// 테마와 짝이 맞지 않는다. 다크 시안이 나오면 [AppColors] 에 다크 토큰을
  /// 추가해 [light] 와 같은 방식으로 조립해야 한다.
  static ThemeData get dark => ThemeData(
        colorSchemeSeed: seedColor,
        brightness: Brightness.dark,
        useMaterial3: true,
      );
}
