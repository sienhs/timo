import 'package:flutter/material.dart';

import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/show_summary.dart';

/// 포스터를 배경으로 깔고 아래에 제목·공연장을 얹은 큰 카드.
///
/// 홈 배너와 검색 결과가 같은 모양을 쓴다. 크기는 부모가 정한다 — 배너는
/// 캐러셀 높이에, 검색 결과는 카드 높이에 맞춰 꽉 채운다.
///
/// [onFavoritePressed] 를 주면 오른쪽 위에 하트가 붙는다(검색 결과). 배너는
/// 넘기는 중에 잘못 눌리기 쉬워 붙이지 않는다.
class ShowBannerCard extends StatelessWidget {
  const ShowBannerCard({
    super.key,
    required this.show,
    required this.onPressed,
    this.onFavoritePressed,
  });

  final ShowSummary show;
  final VoidCallback onPressed;
  final VoidCallback? onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final onFavorite = onFavoritePressed;
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeMetrics.bannerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage.network(
              url: show.posterImageUrl,
              decodeWidth: MediaQuery.sizeOf(context).width,
            ),
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
                  tooltip: HomeStrings.favorite,
                  iconSize: HomeMetrics.favoriteIconSize,
                  color: Colors.white,
                  icon: const Icon(Icons.favorite_border),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
