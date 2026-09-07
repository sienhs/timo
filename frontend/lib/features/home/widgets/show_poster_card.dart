import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_summary.dart';
import 'poster_image.dart';

/// 포스터 + 제목 + 기간으로 된 공연 카드.
///
/// 뱃지를 위젯으로 받는다. 오픈 임박은 오픈 시각을, 인기 공연은 순위를
/// 보여 주는데, 카드가 두 경우를 모두 알면 섹션이 늘 때마다 카드를 고쳐야
/// 한다. 무엇을 얹을지는 섹션이 정한다.
class ShowPosterCard extends StatelessWidget {
  const ShowPosterCard({
    super.key,
    required this.show,
    required this.onPressed,
    this.badge,
    this.width = HomeMetrics.showCardWidth,
  });

  final ShowSummary show;
  final VoidCallback onPressed;
  final Widget? badge;
  final double width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final overlay = badge;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(HomeMetrics.posterRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: HomeMetrics.posterAspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PosterImage(
                      assetPath: show.posterAsset,
                      borderRadius: HomeMetrics.posterRadius,
                      decodeWidth: width,
                    ),
                  ),
                  if (overlay != null)
                    Positioned(
                      left: HomeMetrics.badgeInset,
                      top: HomeMetrics.badgeInset,
                      child: overlay,
                    ),
                ],
              ),
            ),
            const SizedBox(height: HomeMetrics.showCardTitleGap),
            Text(
              show.title,
              style: textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              show.periodLabel,
              style: textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
