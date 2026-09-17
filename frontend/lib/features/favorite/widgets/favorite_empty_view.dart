import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 찜한 것이 하나도 없을 때. 큰 하트 테두리, 제목, 안내 한 줄, 그리고 공연을
/// 둘러보러 가는 버튼.
///
/// 검색어·필터에 걸려 남은 것이 없는 상태와 다르다. 그쪽은 목록 자리에 한 줄
/// 문구만 두고 칩·정렬은 그대로 남긴다(조건을 되돌릴 수 있어야 한다).
class FavoriteEmptyView extends StatelessWidget {
  const FavoriteEmptyView({
    super.key,
    required this.title,
    required this.hint,
    required this.onBrowsePressed,
  });

  final String title;
  final String hint;
  final VoidCallback onBrowsePressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FavoriteMetrics.horizontalPadding,
        FavoriteMetrics.emptyTopGap,
        FavoriteMetrics.horizontalPadding,
        FavoriteMetrics.bottomGap,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.favorite_border,
            size: FavoriteMetrics.emptyIconSize,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: FavoriteMetrics.emptyTitleGap),
          Text(title, style: textTheme.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: FavoriteMetrics.emptyBodyGap),
          Text(hint, style: textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: FavoriteMetrics.emptyActionGap),
          SizedBox(
            width: FavoriteMetrics.emptyActionWidth,
            child: FilledButton(
              onPressed: onBrowsePressed,
              child: const Text(FavoriteStrings.browseShows),
            ),
          ),
        ],
      ),
    );
  }
}
