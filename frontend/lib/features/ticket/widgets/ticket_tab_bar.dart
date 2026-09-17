import 'package:flutter/material.dart';

import '../../../core/widgets/underline_tab_bar.dart';
import '../constants.dart';

/// 내 티켓의 탭. 모양은 공용 [UnderlineTabBar] 고, 여기서는 라벨 순서만 정한다.
///
/// 시안대로 `양도 목록` 탭까지 셋이다. 예정·지난은 예매 목록에서, 양도 목록은
/// 마켓 API 의 내 거래 내역에서 세므로 개수가 따로따로 도착한다([counts]).
class TicketTabBar extends StatelessWidget {
  const TicketTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 탭 순서대로의 개수. 아직 안 불러왔으면 목록 전체가 null 이고, 다른 조회로
  /// 세느라 아직 안 도착한 탭(양도 목록)은 항목이 null 이라 숫자 없이 그린다.
  final List<int?>? counts;

  static const labels = [
    TicketStrings.tabUpcoming,
    TicketStrings.tabPast,
    TicketStrings.tabListings,
  ];

  @override
  Widget build(BuildContext context) {
    return UnderlineTabBar(
      labels: labels,
      counts: counts,
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}
