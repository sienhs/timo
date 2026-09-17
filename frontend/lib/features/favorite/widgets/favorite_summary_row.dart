import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 목록 바로 위의 한 줄. 왼쪽은 `총 4개`, 오른쪽은 정렬 메뉴(`최근 찜한 순 ⌄`).
///
/// 정렬은 [PopupMenuButton] 이 연다. 열림 상태를 화면이 들고 있지 않아도 되고,
/// 고른 항목만 콜백으로 받는다. 공연·아티스트 탭이 항목만 다르게 같은 줄을
/// 쓰므로 라벨 목록과 번호로 받는다.
class FavoriteSummaryRow extends StatelessWidget {
  const FavoriteSummaryRow({
    super.key,
    required this.countLabel,
    required this.sortLabels,
    required this.selectedSort,
    required this.onSortSelected,
  });

  final String countLabel;
  final List<String> sortLabels;
  final int selectedSort;
  final ValueChanged<int> onSortSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FavoriteMetrics.horizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          PopupMenuButton<int>(
            tooltip: FavoriteStrings.sortMenu,
            initialValue: selectedSort,
            onSelected: onSortSelected,
            position: PopupMenuPosition.under,
            color: AppColors.surface,
            itemBuilder: (context) => [
              for (var i = 0; i < sortLabels.length; i++)
                PopupMenuItem(
                  value: i,
                  child: Text(
                    sortLabels[i],
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: i == selectedSort ? FontWeight.w700 : null,
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
                    sortLabels[selectedSort],
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: FavoriteMetrics.sortIconSize,
                    color: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
