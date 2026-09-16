import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 목록 오른쪽 위의 정렬 탭. `인기순 | 마감임박순` 처럼 둘을 세로줄로 잇는다.
///
/// 내 티켓의 `TicketTabBar`(밑줄 달린 큰 탭)와 다르다. 저쪽은 본문이 아예
/// 바뀌는 탭이고 이쪽은 같은 목록의 순서만 바꾸는 자리라, 시안도 작은 글자로
/// 오른쪽에 붙여 두었다.
///
/// 고른 항목은 색과 굵기가 함께 바뀐다. 색만으로 구분하지 않는 규칙은 앱 전체가
/// 같다.
class SortTabRow extends StatelessWidget {
  const SortTabRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '|',
                style: TextStyle(fontSize: 12, color: AppColors.border),
              ),
            ),
          _SortTab(
            label: labels[i],
            selected: i == selectedIndex,
            onTap: () => onSelected(i),
          ),
        ],
      ],
    );
  }
}

class _SortTab extends StatelessWidget {
  const _SortTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
