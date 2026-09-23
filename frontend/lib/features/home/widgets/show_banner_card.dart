import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_stage.dart';
import '../constants.dart';
import '../models/show_summary.dart';

/// 포스터를 자르지 않고 깐 뒤([PosterStage]) 아래에 제목·공연장을 얹은 큰
/// 카드. 검색 결과 목록이 쓰고 크기는 부모가 정한다. [onFavoritePressed] 를 주면
/// 오른쪽 위에 하트가 붙고 [isFavorite] 면 초록으로 채운다. [badge] 는 왼쪽 위다.
class ShowBannerCard extends StatelessWidget {
  const ShowBannerCard({
    super.key,
    required this.show,
    required this.onPressed,
    this.onFavoritePressed,
    this.isFavorite = false,
    this.badge,
  });

  final ShowSummary show;
  final VoidCallback onPressed;
  final VoidCallback? onFavoritePressed;
  final bool isFavorite;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onFavorite = onFavoritePressed;
    final overlay = badge;
    return GestureDetector(
      onTap: onPressed,
      child: PosterStage(
        url: show.posterImageUrl,
        verticalInset: HomeMetrics.searchCardPosterInset,
        borderRadius: HomeMetrics.bannerRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 포스터 밝은 부분에 흰 글자가 묻히지 않게 아래쪽만 어둡게 깐다.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    show.title,
                    style: textTheme.titleMedium?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    show.venueName,
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (overlay != null)
              Positioned(
                top: HomeMetrics.searchCardBadgeInset,
                left: HomeMetrics.searchCardBadgeInset,
                child: overlay,
              ),
            if (onFavorite != null)
              Positioned(
                top: HomeMetrics.favoriteButtonInset,
                right: HomeMetrics.favoriteButtonInset,
                child: IconButton(
                  onPressed: onFavorite,
                  tooltip: isFavorite
                      ? HomeStrings.unfavorite
                      : HomeStrings.favorite,
                  iconSize: HomeMetrics.favoriteIconSize,
                  color: isFavorite ? AppColors.primary : Colors.white,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
