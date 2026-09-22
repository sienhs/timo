import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../routes/app_routes.dart';
import 'models/quick_menu_item.dart';
import 'widgets/mushroom_outline_icon.dart';

/// 하단 바 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
///
/// 바 위젯의 높이는 [barHeight] 뿐이다. 위로 솟은 원형 버튼은 바가 아니라
/// `Scaffold.floatingActionButton` 이 그린다 — 솟은 만큼을 바 높이에 더하면
/// 그 띠가 본문 영역 밖이라 Scaffold 배경(흰색)으로 채워져, 바 위에 흰 층이
/// 하나 더 있는 것처럼 보인다.
class ShellMetrics {
  ShellMetrics._();

  static const barHeight = 64.0;
  static const fabSize = 56.0;
  static const navIconSize = 24.0;
  static const fabIconSize = 30.0;

  /// 원형 버튼이 바 위로 솟는 높이.
  ///
  /// `FloatingActionButtonLocation.centerDocked` 가 버튼 중심을 바의 위쪽
  /// 경계에 놓으므로 반지름만큼 솟는다. 직접 정하는 값이 아니라 그 배치에서
  /// 따라 나오는 값이라, 패널을 얼마나 띄울지 계산할 때 쓰라고 이름만 붙여 둔다.
  static const fabProtrusion = fabSize / 2;

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
/// 기본 아이콘은 Material 아이콘을 쓰고, 버섯은 같은 선 굵기로 그린다.
const quickMenuItems = <QuickMenuItem>[
  // 티켓을 지정하지 않으면 입장 가능한 티켓을 조회해 QR 을 연다.
  QuickMenuItem(
    icon: Icons.qr_code_2,
    label: '입장QR',
    routeName: AppRoutes.entryQr,
  ),
  QuickMenuItem(
    icon: Icons.confirmation_number_outlined,
    label: '마이 티켓',
    routeName: AppRoutes.myTickets,
  ),
  QuickMenuItem(
    icon: Icons.collections_bookmark_outlined,
    label: '컬렉션',
    routeName: AppRoutes.collection,
  ),
  QuickMenuItem(
    icon: Icons.favorite_border,
    label: '찜',
    routeName: AppRoutes.favorites,
  ),
  QuickMenuItem(
    icon: Icons.add_card_outlined,
    customIcon: MushroomOutlineIcon(
      size: ShellMetrics.panelIconSize,
      color: AppColors.textPrimary,
    ),
    label: '버섯 충전',
    routeName: AppRoutes.coinCharge,
  ),
  QuickMenuItem(
    icon: Icons.storefront_outlined,
    label: '양도마켓',
    routeName: AppRoutes.resaleMarket,
  ),
  QuickMenuItem(icon: Icons.menu, label: '카테고리'),
  QuickMenuItem(icon: Icons.settings_outlined, label: '환경 설정'),
];
