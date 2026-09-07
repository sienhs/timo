import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 섹션 제목 한 줄. 오른쪽 '더보기' 는 [onMorePressed] 를 준 섹션에만 붙는다
/// (시안의 인기 아티스트 섹션에는 더보기가 없다).
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.moreLabel,
    this.onMorePressed,
  });

  final String title;
  final String? moreLabel;
  final VoidCallback? onMorePressed;

  @override
  Widget build(BuildContext context) {
    final label = moreLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (label != null && onMorePressed != null)
            // 글자가 작아 InkWell 만으로는 누를 곳이 좁다. TextButton 이
            // 최소 터치 영역을 확보해 준다.
            TextButton(
              onPressed: onMorePressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                textStyle: Theme.of(context).textTheme.bodySmall,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                children: [
                  Text(label),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
