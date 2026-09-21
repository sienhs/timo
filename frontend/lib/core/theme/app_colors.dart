import 'package:flutter/material.dart';

/// 디자인 시안에서 추출한 색 토큰.
///
/// 시안 이미지에서 눈으로 뽑은 근사값이다. Figma 정식 값이 나오면
/// **이 파일만** 교체하면 앱 전체 색이 따라온다. 위젯에서 Color를 직접
/// 쓰지 말고 반드시 여기를 경유한다.
class AppColors {
  AppColors._();

  /// 팀 브랜드 컬러 (S15P21D206-49).
  static const brand = Color(0xFF149F5C);

  /// 주요 액션 버튼, 선택된 좌석. 브랜드 컬러로 통일하기로 정했다.
  ///
  /// 참고로 시안 이미지의 버튼은 이보다 채도가 낮은 #39604D 계열이었다
  /// (색상은 hue 150° 로 동일, 채도만 78% -> 26%). 브랜드 일관성을 택했으므로
  /// 시안보다 밝게 나온다.
  ///
  /// 주의: 흰 글자 대비가 3.43:1 이다. 굵은 16px 버튼 라벨은 WCAG AA 대형
  /// 텍스트 기준(3:1)을 통과하지만, 이 색 위에 **작은** 흰 글자를 올리면
  /// 일반 텍스트 기준(4.5:1)에 미달한다. 그런 자리에는 [primaryPressed] 를
  /// 쓰거나 글자색을 어둡게 가야 한다.
  static const primary = brand;

  /// [primary] 를 20% 어둡게. 눌림 상태와 진한 글자용.
  static const primaryPressed = Color(0xFF107F4A);

  /// [primary] 를 흰 바탕에 아주 옅게 깐 색(약 10%). 고른 칸처럼 브랜드색으로
  /// 바탕을 물들이되 그 위의 검은 글자가 그대로 읽혀야 하는 자리에 쓴다.
  static const primarySurface = Color(0xFFE8F5EF);

  /// 브랜드 강조 색. 금액, 경고, 주의 문구.
  ///
  /// 시안에서 뽑은 값은 채도가 낮은 뮤티드 로즈(#C4756A)였으나, 결제 화면이
  /// 먼저 이 코랄로 머지돼(S15P21D206-139) 두 화면의 강조색이 갈렸다.
  /// 브랜드 쪽으로 통일했다. [AppTheme.accentColor] 가 이 값을 가리킨다.
  static const accent = Color(0xFFFF6B5E);

  // 배치도
  static const zoneFill = Color(0xFFEBD6CE);
  static const stageFill = Color(0xFFC9CDD2);
  static const mapSurface = Color(0xFFF1F1F1);

  /// 잔여좌석·가격 패널의 구역 스와치. 시안은 배치도 구역색(베이지)이 아니라
  /// 회색을 쓴다.
  static const swatch = Color(0xFFD3D3D3);

  // 구역색을 받지 못한 경우의 좌석 기본색. 가능 좌석은 진하게,
  // 선택 좌석은 연한 배경과 진한 테두리로 표시한다.
  static const seatAvailable = Color(0xFF7950B5);
  static const seatSelected = Color(0xFFE7DFF2);
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
