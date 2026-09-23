import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_filters.dart';

/// 공연 전체 화면의 탭 아래 한 줄. 왼쪽은 날짜 칩(`전체 기간` 또는 고른
/// 기간), 오른쪽은 정렬 메뉴(`인기순 ⌄`)다. 기간이 골라져 있으면 칩이 브랜드색
/// 으로 물들고 × 로 바로 풀 수 있다. 시트를 여는 일은 화면이 [onDatePressed]
/// 에서 한다.
class ShowFilterBar extends StatelessWidget {
  const ShowFilterBar({
    super.key,
    required this.range,
    required this.onDatePressed,
    required this.onDateCleared,
    required this.sort,
    required this.onSortSelected,
  });

  final ShowDateRange? range;
  final VoidCallback onDatePressed;
  final VoidCallback onDateCleared;
  final ShowSort sort;
  final ValueChanged<ShowSort> onSortSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
        vertical: HomeMetrics.filterBarVerticalPadding,
      ),
      child: Row(
        children: [
          _DateChip(
            range: range,
            onPressed: onDatePressed,
            onCleared: onDateCleared,
          ),
          const Spacer(),
          _SortMenu(sort: sort, onSelected: onSortSelected),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.range,
    required this.onPressed,
    required this.onCleared,
  });

  final ShowDateRange? range;
  final VoidCallback onPressed;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final range = this.range;
    final active = range != null;
    // 켜진 칩은 옅은 브랜드 바탕 + 진한 브랜드 글자. 꺼진 칩과 글자 굵기도
    // 달라 색만으로 가르지 않는다.
    final background = active ? AppColors.primarySurface : AppColors.surface;
    final foreground = active
        ? AppColors.primaryPressed
        : AppColors.textPrimary;
    final radius = BorderRadius.circular(HomeMetrics.filterChipHeight / 2);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: active ? AppColors.primaryPressed : AppColors.border,
        ),
      ),
      child: SizedBox(
        height: HomeMetrics.filterChipHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.only(
                  left: HomeMetrics.filterChipHorizontalPadding,
                  // × 가 붙으면 그쪽 여백은 버튼이 맡는다.
                  right: active ? 0 : HomeMetrics.filterChipHorizontalPadding,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: HomeMetrics.filterChipIconSize,
                      color: foreground,
                    ),
                    const SizedBox(width: HomeMetrics.filterChipIconGap),
                    Text(
                      range?.label ?? HomeStrings.dateFilterAll,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (active)
              IconButton(
                onPressed: onCleared,
                tooltip: HomeStrings.dateFilterClear,
                iconSize: HomeMetrics.filterChipIconSize,
                color: foreground,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: HomeMetrics.filterChipClearSize,
                  height: HomeMetrics.filterChipClearSize,
                ),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}

/// 정렬 메뉴. 찜 화면의 정렬 메뉴와 같은 모양(글자 + ⌄, 아래로 펼침)이다.
class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSelected});

  final ShowSort sort;
  final ValueChanged<ShowSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopupMenuButton<ShowSort>(
      tooltip: HomeStrings.sortMenu,
      initialValue: sort,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      itemBuilder: (context) => [
        for (final option in ShowSort.values)
          PopupMenuItem(
            value: option,
            child: Text(
              option.label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: option == sort ? FontWeight.w700 : null,
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sort.label,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: HomeMetrics.sortIconSize,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
