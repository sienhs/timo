import 'package:flutter/material.dart';

/// 디자인 시안에서 뽑은 색 토큰. 위젯에서 Color 를 직접 쓰지 말고 반드시 여기를
/// 경유한다. 정식 값이 나오면 이 파일만 바꾸면 앱 전체 색이 따라온다.
class AppColors {
  AppColors._();

  /// 팀 브랜드 컬러.
  static const brand = Color(0xFF149F5C);

  /// 주요 액션 버튼, 선택된 좌석. 브랜드 컬러로 통일한다. 흰 글자 대비가
  /// 3.43:1 이라 굵은 큰 글자는 되지만 작은 흰 글자는 미달이므로 그런 자리에는
  /// [primaryPressed] 를 쓰거나 글자색을 어둡게 간다.
  static const primary = brand;

  /// [primary] 를 20% 어둡게. 눌림 상태와 진한 글자용.
  static const primaryPressed = Color(0xFF107F4A);

  /// [primary] 를 흰 바탕에 아주 옅게 깐 색(약 10%). 고른 칸처럼 브랜드색으로
  /// 바탕을 물들이되 그 위의 검은 글자가 그대로 읽혀야 하는 자리에 쓴다.
  static const primarySurface = Color(0xFFE8F5EF);

  /// 브랜드 강조 색. 금액·경고·주의 문구. [AppTheme.accentColor] 도 이 값이다.
  static const accent = Color(0xFFFF6B5E);

  // 배치도
  static const stageFill = Color(0xFFC9CDD2);
  static const mapSurface = Color(0xFFF1F1F1);

  // 구역색을 받지 못한 경우의 좌석 기본색.
  static const seatAvailable = Color(0xFF7950B5);
  static const seatSold = Color(0xFFD6D6D6);

  /// [primary] 위에 올리는 글자색. 대비가 3.43:1 이므로 굵은 큰 글자에만 쓴다.
  static const onPrimary = Color(0xFFFFFFFF);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F7F7);
  static const border = Color(0xFFE3E3E3);

  static const textPrimary = Color(0xFF1B1B1B);
  static const textSecondary = Color(0xFF686868);
  static const textDisabled = Color(0xFFBDBDBD);

  /// 상태 글자용 색. 장식·금액 강조색(accent)과 분리한다.
  static const error = Color(0xFFB3261E);
  static const warning = Color(0xFF805500);
  static const success = primaryPressed;
}
