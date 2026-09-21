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
  static const onPrimary = Color(0xFFFFFFFF);

  /// [primary] 를 20% 어둡게. 눌림 상태와 진한 글자용.
  ///
  /// 흰 배경 위 **글자**에는 반드시 이쪽을 쓴다. [primary] 는 흰색 대비가
  /// 3.43:1 이라 작은 글자에 쓰면 읽히지 않는다(팬 앱 주석과 같은 이유).
  static const primaryPressed = Color(0xFF107F4A);

  /// 브랜드색을 아주 옅게 깐 바탕. 선택된 공연 줄·강조 칩처럼 "여기" 를
  /// 가리키는 면에 쓴다. 이 위의 글자는 [primaryPressed] 로 간다.
  static const primarySoft = Color(0xFFE7F5ED);

  /// [primarySoft] 로 채운 면의 테두리. 바탕만으로는 흰 배경과 경계가 안 서고,
  /// [primary] 로 두르면 선이 뱃지보다 세게 읽혀 시선이 테두리에 먼저 간다.
  static const primarySoftBorder = Color(0xFFBFE3CE);

  /// 강조·경고 문구. 팬 앱과 같은 코랄.
  static const accent = Color(0xFFFF6B5E);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F7F7);
  static const border = Color(0xFFE3E3E3);

  /// 불러오는 동안 자리를 채워 두는 회색. [surfaceMuted] 보다 한 단계 진해야
  /// 흰 배경 위에서 "빈 칸" 으로 보인다.
  static const skeleton = Color(0xFFECECEC);

  static const textPrimary = Color(0xFF1B1B1B);

  /// 보조 문구. 팬 앱과 같은 값이다.
  ///
  /// 게이트만 한동안 더 옅은 `#8C8C8C` 를 썼는데, 흰 배경 대비가 3.0:1 이라
  /// 본문 기준(4.5:1)에 미달했다. 두 앱이 같은 회색을 쓰는 편이 맞기도 해서
  /// 팬 앱 값으로 맞췄다(대비 5.3:1).
  static const textSecondary = Color(0xFF686868);
  static const textDisabled = Color(0xFFBDBDBD);

  // 스캔 화면. 카메라 위에 올라가므로 어두운 바탕이다.
  static const scanBackground = Color(0xFF111111);
  static const scanOverlay = Color(0x99000000);

  /// 조준 틀 밖을 덮는 반투명 검정. 카메라가 비치되 어디를 봐야 할지 분명하게.
  static const scanScrim = Color(0xB3000000);
  static const onScan = Color(0xFFFFFFFF);

  /// 카메라 위에 올리는 안내 패널. [scanOverlay] 보다 진해 글자가 또렷하다.
  static const scanPanel = Color(0xCC000000);

  /// 카메라 위 보조 문구. 흰색을 그대로 쓰면 안내가 제목만큼 튀어 보인다.
  static const onScanMuted = Color(0xCCFFFFFF);

  // 검증 결과 3종. 색만으로 가르지 않고 항상 문구·아이콘과 함께 쓴다.
  /// 입장 허용. 흰 글자 대비 5.1:1.
  static const admitted = primaryPressed;

  /// 결과 화면 위에 남는 헤더 띠. 본문 색보다 한 단계 진하다 — 같은 색이면
  /// 공연명이 결과 바탕에 묻혀, 어느 공연을 검표하다 난 결과인지 안 읽힌다.
  static const admittedHeader = Color(0xFF0C6238);
  static const rejectedHeader = Color(0xFFB0271E);
  static const undeterminedHeader = Color(0xFF2B2B2B);

  /// 입장 거절. 흰 글자 대비 4.6:1.
  static const rejected = Color(0xFFD93025);

  /// 판정 못 함(네트워크 실패 등). 흰 글자 대비 10:1.
  static const undetermined = Color(0xFF3A3A3A);
}
