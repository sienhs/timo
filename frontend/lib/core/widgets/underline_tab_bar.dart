import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 본문을 통째로 갈아끼우는 큰 탭. 고른 탭 아래에 초록 밑줄이 그어진다.
///
/// 내 티켓(`TicketTabBar`)에 있던 것을 올렸다. 찜리스트가 같은 이유(탭마다
/// 본문이 아예 다른 위젯이고, 옆으로 쓸어 넘기지 않는다)로 같은 탭을 쓰게
/// 되어 두 도메인이 같은 모양을 각자 들고 있을 이유가 없어졌다.
///
/// Material 의 `TabBar` 를 쓰지 않는다. 그쪽은 `TabController` 와 `TabBarView`
/// 를 함께 끌고 오는데, 본문이 아예 다른 위젯이라 얻을 게 없다.
///
/// 개수([counts])는 라벨 뒤에 붙는다(`공연 4`). 세어 본 적이 없는 탭은 항목을
/// null 로 주면 숫자 없이 그린다 — 0 을 먼저 찍었다가 실제 값으로 바뀌면
/// "없다" 고 읽었다가 번복되는 꼴이 된다.
class UnderlineTabBar extends StatelessWidget {
  const UnderlineTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// 탭 순서대로의 개수. 목록 전체가 null 이면 어느 탭도 숫자를 찍지 않는다.
  final List<int?>? counts;

  @override
  Widget build(BuildContext context) {
    final counts = this.counts;
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
                count: counts == null ? null : counts[i],
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
