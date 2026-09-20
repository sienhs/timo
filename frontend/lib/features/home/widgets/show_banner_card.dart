import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_stage.dart';
import '../constants.dart';
import '../models/show_summary.dart';

/// 포스터를 자르지 않고 깐 뒤([PosterStage]) 아래에 제목·공연장을 얹은 큰
/// 카드. 검색 결과 목록이 쓴다. 크기는 부모가 정한다 — 카드 높이에 맞춰
/// 꽉 채운다.
///
/// 홈 배너도 한때 이 카드를 썼지만 [HomeBannerCard] 로 갈라졌다. 포스터를
/// 다루는 방식은 같지만, 배너는 첫 화면을 차지하는 큰 그림이라 글자 크기와
/// 줄 수가 목록 한 줄과 다르게 움직인다.
///
/// [onFavoritePressed] 를 주면 오른쪽 위에 하트가 붙는다. 찜한 공연([isFavorite])은
/// 하트가 초록으로 채워진다 — 흰 빈 하트와 채운 초록 하트가 앱 공통의 찜
/// 표시다. 상태는 화면이 알고 카드는 받은 대로 그린다.
class ShowBannerCard extends StatelessWidget {
  const ShowBannerCard({
    super.key,
    required this.show,
    required this.onPressed,
    this.onFavoritePressed,
    this.isFavorite = false,
  });

  final ShowSummary show;
  final VoidCallback onPressed;
  final VoidCallback? onFavoritePressed;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onFavorite = onFavoritePressed;
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
