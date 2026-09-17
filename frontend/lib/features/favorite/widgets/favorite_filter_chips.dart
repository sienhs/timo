import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/favorite_filters.dart';

/// 공연 탭의 판매 상태 칩 줄. `전체 4 · 판매 중 3 · 판매 종료 1`.
///
/// 개수는 검색어와 상관없이 찜한 공연 전체에서 센다 — 칩은 "무엇이 얼마나
/// 있는가" 를 알리는 자리라, 검색으로 좁힌 수를 찍으면 검색어를 지울 때마다
/// 숫자가 널뛴다.
class FavoriteFilterChips extends StatelessWidget {
  const FavoriteFilterChips({
    super.key,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  /// 필터별 개수. [FavoriteShowFilter.values] 순서다.
  final Map<FavoriteShowFilter, int> counts;
  final FavoriteShowFilter selected;
  final ValueChanged<FavoriteShowFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FavoriteMetrics.filterChipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: FavoriteMetrics.horizontalPadding,
        ),
        children: [
          for (final filter in FavoriteShowFilter.values) ...[
            if (filter != FavoriteShowFilter.values.first)
              const SizedBox(width: FavoriteMetrics.filterChipGap),
            _FilterChip(
              label: '${filter.label} ${counts[filter] ?? 0}',
              selected: filter == selected,
              onTap: () => onSelected(filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 고른 칩은 [AppColors.primaryPressed] 위에 흰 글자다. 브랜드 그린 위의
    // 흰 글자는 작은 글자 대비 기준(4.5:1)에 못 미친다(`AppColors.primary`
    // 주석). 색만으로 구분하지 않도록 굵기도 함께 바꾼다.
    final background = selected ? AppColors.primaryPressed : AppColors.surface;
    final foreground = selected ? AppColors.onPrimary : AppColors.textPrimary;
    final radius = BorderRadius.circular(FavoriteMetrics.filterChipHeight / 2);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.primaryPressed : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FavoriteMetrics.filterChipHorizontalPadding,
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
