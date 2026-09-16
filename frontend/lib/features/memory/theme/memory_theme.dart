import 'package:flutter/material.dart';

import 'timo_colors.dart';

export 'timo_colors.dart';

/// App chrome: white paper with TIMO green. Collection and creator screens
/// run on this theme; the ticket viewer switches to [timoDarkTheme] because
/// the stage effects are tuned against a dark backdrop.
ThemeData timoTheme() {
  const scheme = ColorScheme.light(
    primary: TimoColors.brandMid,
    onPrimary: Colors.white,
    secondary: TimoColors.brand,
    surface: TimoColors.paper,
    onSurface: TimoColors.ink,
    error: TimoColors.dangerInk,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: TimoColors.paper,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: TimoColors.ink, displayColor: TimoColors.ink)
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.28,
            letterSpacing: -0.8,
            color: TimoColors.ink,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: TimoColors.ink,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: TimoColors.inkSecondary,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: TimoColors.inkTertiary,
          ),
        ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: TimoColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TimoColors.ink,
      shape: Border(bottom: BorderSide(color: TimoColors.line)),
      titleTextStyle: TextStyle(
        color: TimoColors.brandMid,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TimoColors.inkSecondary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TimoColors.brandMid,
        side: const BorderSide(color: TimoColors.brandMid, width: 1.2),
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TimoRadii.tile),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: TimoColors.paperMuted,
      selectedColor: TimoColors.brandSoft,
      side: const BorderSide(color: TimoColors.line),
      labelStyle: const TextStyle(
        color: TimoColors.ink,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TimoColors.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TimoRadii.panel),
      ),
      titleTextStyle: const TextStyle(
        color: TimoColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: TimoColors.inkSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TimoColors.paper,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TimoColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: TimoColors.brandMid,
      inactiveTrackColor: TimoColors.line,
      thumbColor: TimoColors.brandMid,
      overlayColor: Color(0x333A9A63),
    ),
    dividerTheme: const DividerThemeData(color: TimoColors.line),
    iconTheme: const IconThemeData(color: TimoColors.ink),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TimoColors.brandMid,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// The original dark "stage" theme, kept for the ticket viewer, the
/// immersive video page and the volumetric lab.
ThemeData timoDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: TimoColors.accent,
    onPrimary: Color(0xFF04140A),
    secondary: TimoColors.cyan,
    surface: TimoColors.backgroundElevated,
    onSurface: TimoColors.textPrimary,
    error: TimoColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TimoColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: TimoColors.textPrimary,
          displayColor: TimoColors.textPrimary,
        )
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.25,
            letterSpacing: -0.8,
            color: TimoColors.textPrimary,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: TimoColors.textPrimary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: TimoColors.textSecondary,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: TimoColors.textTertiary,
          ),
        ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TimoColors.textPrimary,
      titleTextStyle: TextStyle(
        color: TimoColors.textSecondary,
        fontSize: 13,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TimoColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TimoRadii.tile),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TimoColors.backgroundElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TimoRadii.panel),
        side: const BorderSide(color: TimoColors.glassBorder),
      ),
      titleTextStyle: const TextStyle(
        color: TimoColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: TimoColors.textSecondary,
        fontSize: 14,
        height: 1.5,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TimoColors.backgroundElevated,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1A2133),
      contentTextStyle: const TextStyle(color: TimoColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TimoColors.glassBorder),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: TimoColors.accent,
      inactiveTrackColor: TimoColors.glassStrong,
      thumbColor: TimoColors.accentSoft,
      overlayColor: Color(0x334ADE80),
    ),
    dividerTheme: const DividerThemeData(color: TimoColors.glassBorder),
    iconTheme: const IconThemeData(color: TimoColors.textPrimary),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TimoColors.accent,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
