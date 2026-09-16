import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 내 티켓의 탭. 고른 탭 아래에 초록 밑줄이 그어진다.
///
/// 시안대로 `양도 목록` 탭까지 셋이다. 예정·지난은 예매 목록에서, 양도 목록은
/// 마켓 API 의 내 거래 내역에서 세므로 개수가 따로따로 도착한다([counts]).
///
/// Material 의 `TabBar` 를 쓰지 않는다. 그쪽은 `TabController` 와 `TabBarView`
/// 를 함께 끌고 오는데, 여기서는 탭마다 본문이 아예 다른 위젯이고 옆으로
/// 쓸어 넘기지도 않아서 얻을 게 없다.
///
/// 개수는 불러오기 전에는 null 이라 숫자 없이 그린다. 0 을 먼저 찍었다가
/// 실제 값으로 바뀌면 "없다" 고 읽었다가 번복되는 꼴이 된다.
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
  /// 0 을 찍으면 "없다" 고 단정하는 꼴인데, 세어 본 적이 없는 것과 없는 것은 다르다.
  final List<int?>? counts;

  static const labels = [
    TicketStrings.tabUpcoming,
    TicketStrings.tabPast,
    TicketStrings.tabListings,
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: _Tab(
                label: labels[i],
                count: counts == null ? null : counts![i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 색만으로 구분하지 않도록 고른 탭은 굵기도 함께 바꾼다. 하단 바와 같은 규칙이다.
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            count == null ? label : '$label $count',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
