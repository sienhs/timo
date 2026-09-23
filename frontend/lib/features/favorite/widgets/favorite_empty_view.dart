import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 목록 자리에 보여 줄 것이 없을 때. 큰 하트 테두리, 제목, 안내 한 줄, 여기서
/// 할 수 있는 일 하나(공연 둘러보기 · 로그인). 검색어·필터에 걸려 빈 상태는
/// 이걸 쓰지 않고 한 줄 문구만 둔다.
class FavoriteEmptyView extends StatelessWidget {
  const FavoriteEmptyView({
    super.key,
    required this.title,
    required this.hint,
    required this.onActionPressed,
    this.actionLabel = FavoriteStrings.browseShows,
  });

  final String title;
  final String hint;
  final VoidCallback onActionPressed;

  /// 버튼에 적을 말. 기본은 '공연 둘러보기' 다.
  final String actionLabel;

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
              onPressed: onActionPressed,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
