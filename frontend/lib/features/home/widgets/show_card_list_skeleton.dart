import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';

/// 큰 공연 카드([ShowBannerCard])가 세로로 쌓인 목록의 뼈대.
///
/// 목록 화면과 검색 결과가 함께 쓴다. 두 곳이 같은 카드를 같은 높이·간격으로
/// 세우므로, 뼈대가 갈라지면 한쪽만 자리가 안 맞게 된다.
///
/// 스스로 구르지 않는다. 부모가 ListView 인 자리(검색 결과)와 남은 높이를
/// 채워야 하는 자리(목록 화면)가 둘 다 있어, 스크롤은 부모가 정한다.
class ShowCardListSkeleton extends StatelessWidget {
  const ShowCardListSkeleton({
    super.key,
    this.count = HomeMetrics.skeletonCardCount,
  });

  /// 그릴 빈 카드 수.
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < count; index++)
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HomeMetrics.horizontalPadding,
              0,
              HomeMetrics.horizontalPadding,
              HomeMetrics.searchCardGap,
            ),
            child: SizedBox(
              height: HomeMetrics.searchCardHeight,
              child: SkeletonBox(radius: HomeMetrics.bannerRadius),
            ),
          ),
      ],
    );
  }
}
