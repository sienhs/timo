import 'package:flutter/material.dart';

import '../constants.dart';
import 'skeleton_box.dart';

/// 배너를 불러오는 동안 그 자리에 두는 빈 배너. 높이와 여백을
/// [HomeBannerCarousel] 과 같게 잡아, 데이터가 오는 순간 아래 섹션이 밀리지
/// 않게 한다. 페이지 점 줄까지 같은 높이로 비워 둔다.
class HomeBannerSkeleton extends StatelessWidget {
  const HomeBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: HomeStrings.loading,
      child: Column(
        children: [
          SizedBox(
            height: HomeMetrics.bannerHeightOf(MediaQuery.sizeOf(context)),
            child: const Padding(
              // 캐러셀이 배너 양옆에 두는 여백과 같다.
              padding: EdgeInsets.symmetric(
                horizontal: HomeMetrics.bannerGap / 2,
              ),
              child: SkeletonBox(radius: HomeMetrics.bannerRadius),
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: HomeMetrics.bannerIndicatorSize),
        ],
      ),
    );
  }
}
