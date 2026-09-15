import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_summary.dart';
import 'show_banner_card.dart';

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

  /// 배너로 보여 줄 공연. 비어 있으면 아무것도 그리지 않는다.
  final List<ShowSummary> banners;
  final ValueChanged<ShowSummary> onBannerPressed;

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
    if (widget.banners.isEmpty) return const SizedBox.shrink();
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
              child: ShowBannerCard(
                show: widget.banners[index],
                onPressed: () => widget.onBannerPressed(widget.banners[index]),
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
