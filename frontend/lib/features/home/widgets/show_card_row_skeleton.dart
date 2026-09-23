import 'package:flutter/material.dart';

import '../constants.dart';
import '../../../core/widgets/skeleton_box.dart';

/// 공연 카드 줄을 불러오는 동안 그 자리에 두는 빈 카드들.
///
/// 크기와 간격을 [ShowPosterCard] 와 같게 잡아, 데이터가 오는 순간 자리가
/// 밀리지 않게 한다. 스피너 하나만 두면 줄 높이를 알 수 없어 아래 섹션이
/// 위로 붙었다가 다시 내려온다.
class ShowCardRowSkeleton extends StatelessWidget {
  const ShowCardRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제 카드 줄과 같은 가로 스크롤 안에 둔다. 폰 폭보다 넓은 줄을 Row 로만
    // 두면 넘친다. 빈 카드를 넘겨 볼 일은 없으니 스크롤은 잠근다.
    return Semantics(
      label: HomeStrings.loading,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: HomeMetrics.horizontalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < HomeMetrics.skeletonCardCount; index++)
              Padding(
                padding: EdgeInsets.only(
                  right: index == HomeMetrics.skeletonCardCount - 1
                      ? 0
                      : HomeMetrics.showCardGap,
                ),
                child: const _SkeletonCard(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 글자 줄의 높이를 실제 글꼴에서 가져와 카드 높이가 데이터 카드와 같게 한다.
    final titleHeight = textTheme.titleSmall?.fontSize ?? 14;
    final periodHeight = textTheme.labelMedium?.fontSize ?? 12;
    return SizedBox(
      width: HomeMetrics.showCardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: HomeMetrics.posterAspectRatio,
            child: SkeletonBox(radius: HomeMetrics.posterRadius),
          ),
          const SizedBox(height: HomeMetrics.showCardTitleGap),
          SizedBox(
            width: HomeMetrics.showCardWidth * 0.8,
            height: titleHeight,
            child: const SkeletonBox(radius: HomeMetrics.badgeRadius),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: HomeMetrics.showCardWidth * 0.5,
            height: periodHeight,
            child: const SkeletonBox(radius: HomeMetrics.badgeRadius),
          ),
        ],
      ),
    );
  }
}
