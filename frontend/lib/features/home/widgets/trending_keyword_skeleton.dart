import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';

/// 실시간 인기 검색어를 불러오는 동안 그 자리에 두는 뼈대.
///
/// 제목 줄과 순위 줄들을 [TrendingKeywordList] 와 같은 높이로 세운다. 이
/// 섹션은 열 줄짜리([HomeMetrics.trendingCount]) 긴 목록이라, 스피너 하나만
/// 두면 화면 절반이 비었다가 한 번에 채워진다.
class TrendingKeywordSkeleton extends StatelessWidget {
  const TrendingKeywordSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleHeight = textTheme.titleMedium?.fontSize ?? 16;
    final keywordHeight = textTheme.bodyLarge?.fontSize ?? 16;

    return Semantics(
      label: HomeStrings.loading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.horizontalPadding,
            ),
            child: SizedBox(
              width: HomeMetrics.skeletonSectionTitleWidth,
              height: titleHeight,
              child: const SkeletonBox(radius: HomeMetrics.badgeRadius),
            ),
          ),
          const SizedBox(height: HomeMetrics.sectionTitleGap),
          for (var rank = 0; rank < HomeMetrics.trendingCount; rank++)
            SizedBox(
              height: HomeMetrics.trendingRowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HomeMetrics.horizontalPadding,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: HomeMetrics.skeletonRankWidth,
                      height: keywordHeight,
                      child: const SkeletonBox(radius: HomeMetrics.badgeRadius),
                    ),
                    const SizedBox(
                      width:
                          HomeMetrics.trendingRankWidth -
                          HomeMetrics.skeletonRankWidth,
                    ),
                    // 검색어 길이가 줄마다 다르니 뼈대도 번갈아 다르게 둔다.
                    // 같은 길이로 늘어놓으면 목록이 아니라 표처럼 보인다.
                    SizedBox(
                      width: rank.isEven
                          ? HomeMetrics.skeletonKeywordWideWidth
                          : HomeMetrics.skeletonKeywordNarrowWidth,
                      height: keywordHeight,
                      child: const SkeletonBox(radius: HomeMetrics.badgeRadius),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
