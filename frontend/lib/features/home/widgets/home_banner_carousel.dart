import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/home_banner.dart';
import 'poster_image.dart';

/// 상단 배너 캐러셀. 옆으로 넘길 수 있다는 걸 알리려고 다음 배너가 오른쪽에
/// 살짝 걸쳐 보이게 한다([HomeMetrics.bannerViewportFraction]).
///
/// 자동 넘김은 넣지 않았다. 읽는 중에 화면이 바뀌면 눌러야 할 배너가 도망가고,
/// 접근성 측면에서도 사용자가 멈출 방법을 함께 줘야 한다. 기획에서 요구하면
/// 그때 일시정지까지 같이 만든다.
class HomeBannerCarousel extends StatefulWidget {
  const HomeBannerCarousel({
    super.key,
    required this.banners,
    required this.onBannerPressed,
  });

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onBannerPressed;

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: HomeMetrics.bannerViewportFraction,
  );
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: HomeMetrics.bannerHeight,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: widget.banners.length,
            itemBuilder: (context, index) => Padding(
              // 좌우 반씩 나눠 두면 배너 사이 간격이 되고, 첫 배너의 왼쪽
              // 끝이 섹션 제목의 여백과 거의 맞는다(폭 375 기준).
              padding: const EdgeInsets.symmetric(
                horizontal: HomeMetrics.bannerGap / 2,
              ),
              child: _BannerCard(
                banner: widget.banners[index],
                onPressed: () =>
                    widget.onBannerPressed(widget.banners[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _PageDots(count: widget.banners.length, current: _currentPage),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner, required this.onPressed});

  final HomeBanner banner;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onPressed,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(HomeMetrics.bannerRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(
              assetPath: banner.posterAsset,
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
                    banner.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    banner.subtitle,
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white70,
                    ),
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

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isCurrent = index == current;
        return Container(
          width: HomeMetrics.bannerIndicatorSize,
          height: HomeMetrics.bannerIndicatorSize,
          margin: const EdgeInsets.symmetric(
            horizontal: HomeMetrics.bannerIndicatorGap / 2,
          ),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent ? AppColors.brand : AppColors.border,
          ),
        );
      }),
    );
  }
}
