import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/show_summary.dart';

/// 검색 결과 한 줄. 작은 포스터 + 제목 · 기간 · 공연장.
///
/// 홈의 세로 카드([ShowPosterCard])를 그대로 세로 목록에 쓰면 한 화면에
/// 두 건밖에 안 들어간다. 검색 결과는 훑어 내리는 목록이라 가로 줄이 맞다.
class ShowSearchResultTile extends StatelessWidget {
  const ShowSearchResultTile({
    super.key,
    required this.show,
    required this.onPressed,
  });

  final ShowSummary show;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final secondary = textTheme.labelMedium?.copyWith(
      color: AppColors.textSecondary,
    );
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeMetrics.horizontalPadding,
          vertical: HomeMetrics.searchTileVerticalPadding,
        ),
        child: Row(
          children: [
            SizedBox(
              width: HomeMetrics.searchThumbWidth,
              child: AspectRatio(
                aspectRatio: HomeMetrics.posterAspectRatio,
                child: PosterImage.network(
                  url: show.posterImageUrl,
                  borderRadius: HomeMetrics.searchThumbRadius,
                  decodeWidth: HomeMetrics.searchThumbWidth,
                ),
              ),
            ),
            const SizedBox(width: HomeMetrics.searchTileGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    style: textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(show.periodLabel, style: secondary, maxLines: 1),
                  Text(
                    show.venueName,
                    style: secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
