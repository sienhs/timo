import 'package:flutter/material.dart';

import '../../../core/widgets/poster_stage.dart';
import '../constants.dart';
import '../models/show_summary.dart';

/// 홈 맨 위 캐러셀에 올리는 배너 한 장.
///
/// 포스터를 자르지 않고([PosterStage]) 그 위 왼쪽 아래에 공연명 · 공연장 ·
/// 날짜를 쌓는다. 홈에 처음 들어온 사람이 "무슨 공연이 언제 어디서" 까지를
/// 배너 한 장에서 읽게 하려는 자리라, 공연명은 화면에서 가장 큰 글씨다.
///
/// 검색 결과의 `ShowBannerCard` 와 생김새가 비슷하지만 나누어 둔다. 저쪽은
/// 목록의 한 줄이라 높이가 고정이고 찜 하트가 붙고, 이쪽은 첫 화면을 차지하는
/// 큰 그림이라 글자 크기와 줄 수가 다르게 움직인다. 하나로 묶으면 "배너일
/// 때만" 이라는 조건이 위젯 안에 쌓인다.
///
/// 하트를 붙이지 않는 것은 그대로 둔다 — 넘기는 중에 잘못 눌리기 쉽다.
class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({
    super.key,
    required this.show,
    required this.onPressed,
  });

  final ShowSummary show;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onPressed,
      child: PosterStage(
        url: show.posterImageUrl,
        verticalInset: HomeMetrics.bannerPosterInset,
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
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
            Positioned(
              left: HomeMetrics.bannerTextInset,
              right: HomeMetrics.bannerTextInset,
              bottom: HomeMetrics.bannerTextInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    show.title,
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: HomeMetrics.bannerTextGap),
                  Text(
                    show.venueName,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    show.periodLabel,
                    style: textTheme.bodySmall?.copyWith(color: Colors.white70),
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
