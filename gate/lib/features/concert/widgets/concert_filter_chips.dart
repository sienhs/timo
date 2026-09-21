import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../constants.dart';
import '../models/concert_filter.dart';

/// 목록 위 필터 칩 줄. 고른 것 하나가 진하게 채워진다.
///
/// 개수를 여기서 세지 않고 [counts] 로 받는다. 세는 기준이 되는 "지금" 은
/// 목록 전체가 공유해야 하는 값이라([ConcertTile] 의 `isToday` 와 같은 이유)
/// 화면이 한 번 정해 정렬·판정·개수에 같이 쓴다.
class ConcertFilterChips extends StatelessWidget {
  const ConcertFilterChips({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  final Map<ConcertFilter, int> counts;
  final ConcertFilter selected;
  final ValueChanged<ConcertFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.pagePadding),
      child: Row(
        children: [
          for (final filter in ConcertFilter.values) ...[
            _FilterChip(
              label: ConcertStrings.filterChip(filter.label, counts[filter] ?? 0),
              selected: filter == selected,
              onPressed: () => onSelected(filter),
            ),
            if (filter != ConcertFilter.values.last)
              const SizedBox(width: ConcertMetrics.chipGap),
          ],
        ],
      ),
    );
  }
}

/// 칩 한 개.
///
/// Material 의 `FilterChip` 을 쓰지 않는다. 그쪽은 고른 칩에 체크 아이콘이
/// 붙고 높이·여백이 테마에 묶여 있어, 여기서 원하는 "글자만 든 알약" 모양을
/// 만들려면 지우는 설정이 그리는 설정보다 많아진다.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.textPrimary : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(ConcertMetrics.chipRadius),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(ConcertMetrics.chipRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
