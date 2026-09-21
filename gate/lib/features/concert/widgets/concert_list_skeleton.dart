import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';

/// 공연 목록을 불러오는 동안 그 자리에 두는 빈 카드들.
///
/// 크기를 [ConcertTile] 과 같게 잡아, 목록이 도착하는 순간 카드가 밀리지 않는다.
/// 스피너 하나만 두면 화면이 비었다가 갑자기 채워져 무엇을 기다렸는지 모른다.
///
/// 필터 칩 자리는 비워 둔다. 칩에 붙는 숫자는 목록을 받아 봐야 아는 값이라
/// 빈 칩을 먼저 그리면 0 이 잠깐 보였다 바뀐다.
class ConcertListSkeleton extends StatelessWidget {
  const ConcertListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '공연 목록을 불러오는 중',
      // 빈 상자들을 하나씩 읽어 줄 이유가 없다.
      excludeSemantics: true,
      child: ListView.separated(
        // 빈 카드를 넘겨 볼 일은 없으니 스크롤은 잠근다.
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.pagePadding,
          0,
          AppMetrics.pagePadding,
          AppMetrics.pagePadding,
        ),
        itemCount: ConcertMetrics.skeletonTileCount,
        separatorBuilder: (_, _) =>
            const SizedBox(height: ConcertMetrics.cardGap),
        itemBuilder: (context, index) => const _SkeletonTile(),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 글자 줄 높이를 실제 글꼴에서 가져와 데이터 카드와 높이가 같게 한다.
    final titleHeight = textTheme.titleMedium?.fontSize ?? 16;
    final bodyHeight = textTheme.bodySmall?.fontSize ?? 13;

    return Container(
      constraints: const BoxConstraints(
        minHeight: ConcertMetrics.tileMinHeight,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConcertMetrics.cardRadius),
        border: Border.all(
          color: AppColors.border,
          width: ConcertMetrics.cardBorderWidth,
        ),
      ),
      padding: const EdgeInsets.all(ConcertMetrics.cardPadding),
      child: Row(
        children: [
          SizedBox(
            width: ConcertMetrics.posterWidth,
            child: const AspectRatio(
              aspectRatio: ConcertMetrics.posterAspectRatio,
              child: SkeletonBox(radius: ConcertMetrics.posterRadius),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: titleHeight, child: const SkeletonBox()),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.6,
                  child: SizedBox(
                    height: bodyHeight,
                    child: const SkeletonBox(),
                  ),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.45,
                  child: SizedBox(
                    height: bodyHeight,
                    child: const SkeletonBox(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
