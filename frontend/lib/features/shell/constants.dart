import 'package:flutter/material.dart';

import 'models/quick_menu_item.dart';

/// 하단 바 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
///
/// 원형 버튼이 바 위로 [fabLift] 만큼 솟아 있어서, 바 위젯의 전체 높이는
/// [barHeight] 가 아니라 [fabLift] + [barHeight] 다. 이 값을 나눠 두지 않으면
/// 버튼이 위젯 박스 밖으로 나가 탭이 먹지 않는다.
class ShellMetrics {
  ShellMetrics._();

  static const barHeight = 64.0;
  static const fabSize = 56.0;
  static const fabLift = 24.0;
  static const navIconSize = 24.0;
  static const fabIconSize = 30.0;

  /// 바 위젯이 차지하는 높이(하단 안전 영역 제외).
  static const barTotalHeight = fabLift + barHeight;

  /// 빠른 메뉴 패널과 바 사이 간격.
  static const panelGap = 12.0;
  static const panelHorizontalMargin = 12.0;
  static const panelRadius = 16.0;
  static const panelIconSize = 28.0;
  static const quickMenuColumns = 4;

  /// 패널 등장 연출. 값이 커지면 메뉴를 여는 게 굼떠 보인다.
  static const panelTransition = Duration(milliseconds: 180);
  static const panelSlideOffset = Offset(0, 0.06);
}

/// 셸에서 쓰는 문구.
class ShellStrings {
  ShellStrings._();

  static const homeTab = '홈';
  static const myPageTab = '마이페이지';
  static const quickMenuTab = '빠른 메뉴';

  static const openQuickMenu = '빠른 메뉴 열기';
  static const quickMenuBarrier = '빠른 메뉴 닫기';

  /// 화면이 아직 없는 빠른 메뉴 항목을 눌렀을 때.
  static String notReady(String label) => '$label 화면은 준비 중이에요.';
}

/// 빠른 메뉴 격자. 순서가 시안(4열 × 2행)의 순서다.
///
/// 아이콘은 시안의 커스텀 아이콘을 Material 아이콘으로 근사한 것이다.
/// 아이콘 에셋이 나오면 이 목록만 교체하면 된다.
const quickMenuItems = <QuickMenuItem>[
  QuickMenuItem(icon: Icons.qr_code_2, label: '입장QR'),
  QuickMenuItem(icon: Icons.confirmation_number_outlined, label: '마이 티켓'),
  QuickMenuItem(icon: Icons.collections_bookmark_outlined, label: '컬렉션'),
  QuickMenuItem(icon: Icons.favorite_border, label: '찜'),
  QuickMenuItem(icon: Icons.savings_outlined, label: '코인 충전'),
  QuickMenuItem(icon: Icons.storefront_outlined, label: '양도마켓'),
  QuickMenuItem(icon: Icons.menu, label: '카테고리'),
  QuickMenuItem(icon: Icons.settings_outlined, label: '환경 설정'),
];
