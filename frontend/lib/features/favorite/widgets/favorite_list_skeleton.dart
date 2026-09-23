import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';

/// 찜한 공연을 불러오는 동안 공연 탭 자리에 두는 뼈대. 상태 칩 줄 · '총 N개'
/// 줄 · 카드 몇 장을 실제 탭과 같은 높이로 세워 화면 위쪽이 들썩이지 않게 한다.
class FavoriteListSkeleton extends StatelessWidget {
  const FavoriteListSkeleton({super.key});

  /// 그릴 빈 카드 수. 폰 한 화면에 들어가는 만큼이다.
  static const _cardCount = 4;

  /// 칩 하나의 폭. '판매 종료 1' 정도를 덮는 길이다.
  static const _chipWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summaryHeight = textTheme.bodyMedium?.fontSize ?? 14;

    return Semantics(
      label: FavoriteStrings.loading,
      child: ListView(
        // 뼈대를 굴려 볼 일은 없다.
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: FavoriteMetrics.bottomGap),
        children: [
          SizedBox(
            height: FavoriteMetrics.filterChipHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: FavoriteMetrics.horizontalPadding,
              ),
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0)
                    const SizedBox(width: FavoriteMetrics.filterChipGap),
                  const SizedBox(
                    width: _chipWidth,
                    child: SkeletonBox(
                      radius: FavoriteMetrics.filterChipHeight / 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: FavoriteMetrics.filterRowBottomGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FavoriteMetrics.horizontalPadding,
            ),
            child: SizedBox(
              width: FavoriteMetrics.emptyActionWidth,
              height: summaryHeight,
              child: const SkeletonBox(
                radius: FavoriteMetrics.statusBadgeRadius,
              ),
            ),
          ),
          const SizedBox(height: FavoriteMetrics.summaryRowBottomGap),
          for (var i = 0; i < _cardCount; i++)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                FavoriteMetrics.horizontalPadding,
                0,
                FavoriteMetrics.horizontalPadding,
                FavoriteMetrics.showCardGap,
              ),
              child: SizedBox(
                height: _cardHeight,
                child: SkeletonBox(radius: FavoriteMetrics.showCardRadius),
              ),
            ),
        ],
      ),
    );
  }

  /// 카드 높이. 안쪽 여백 + 포스터 높이라 실제 카드와 같다.
  static const _cardHeight =
      FavoriteMetrics.showCardPadding * 2 +
      FavoriteMetrics.posterWidth / FavoriteMetrics.posterAspectRatio;
}
