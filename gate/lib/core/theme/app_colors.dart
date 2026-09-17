import 'package:flutter/material.dart';

/// 게이트 앱의 색 토큰. 팬 앱(`frontend/`)의 브랜드 값을 그대로 쓴다.
///
/// 위젯에서 Color 를 직접 쓰지 말고 반드시 여기를 경유한다. 검증 결과 색은
/// 야외 게이트에서 팔 뻗은 거리로도 읽혀야 하므로 흰 글자 대비 4.5:1 이상인
/// 진한 값으로 골랐다(주석에 대비 값 표기).
class AppColors {
  AppColors._();

  /// 팀 브랜드 컬러 (S15P21D206-49).
  static const brand = Color(0xFF149F5C);
  static const primary = brand;

  /// [primary] 를 20% 어둡게. 눌림 상태와 진한 글자용.
  static const primaryPressed = Color(0xFF107F4A);

  /// 강조·경고 문구. 팬 앱과 같은 코랄.
  static const accent = Color(0xFFFF6B5E);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F7F7);
  static const border = Color(0xFFE3E3E3);

  static const textPrimary = Color(0xFF1B1B1B);
  static const textSecondary = Color(0xFF8C8C8C);
  static const textDisabled = Color(0xFFBDBDBD);

  // 스캔 화면. 카메라 위에 올라가므로 어두운 바탕이다.
  static const scanBackground = Color(0xFF111111);
  static const scanOverlay = Color(0x99000000);

  /// 조준 틀 밖을 덮는 반투명 검정. 카메라가 비치되 어디를 봐야 할지 분명하게.
  static const scanScrim = Color(0xB3000000);
  static const onScan = Color(0xFFFFFFFF);

  // 검증 결과 3종. 색만으로 가르지 않고 항상 문구·아이콘과 함께 쓴다.
  /// 입장 허용. 흰 글자 대비 5.1:1.
  static const admitted = primaryPressed;

  /// 입장 거절. 흰 글자 대비 4.6:1.
  static const rejected = Color(0xFFD93025);

  /// 판정 못 함(네트워크 실패 등). 흰 글자 대비 10:1.
  static const undetermined = Color(0xFF3A3A3A);
}
