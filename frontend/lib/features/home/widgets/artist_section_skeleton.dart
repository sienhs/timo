import 'package:flutter/material.dart';

import '../constants.dart';
import '../../../core/widgets/skeleton_box.dart';

/// 아티스트 아바타 격자를 불러오는 동안 그 자리에 두는 빈 격자. 칸 수·폭·간격을
/// `ArtistSection` 과 같게 잡아 데이터가 오는 순간 아래 섹션이 밀리지 않게 한다.
/// 홈의 인기 아티스트는 두 줄, 검색 화면의 추천 검색어는 한 줄이라 [rows] 로 갈린다.
class ArtistSectionSkeleton extends StatelessWidget {
  const ArtistSectionSkeleton({super.key, this.rows = 2});

  /// 그릴 줄 수.
  final int rows;

  @override
  Widget build(BuildContext context) {
    final nameHeight = Theme.of(context).textTheme.bodySmall?.fontSize ?? 12;
    return Semantics(
      label: HomeStrings.loading,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HomeMetrics.horizontalPadding,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / HomeMetrics.artistColumns;
            return Wrap(
              runSpacing: HomeMetrics.artistRowGap,
              children: [
                for (var i = 0; i < HomeMetrics.artistColumns * rows; i++)
                  SizedBox(
                    width: cellWidth,
                    child: Column(
                      children: [
                        const SizedBox(
                          width: HomeMetrics.artistAvatarSize,
                          height: HomeMetrics.artistAvatarSize,
                          child: SkeletonBox(
                            radius: HomeMetrics.artistAvatarSize / 2,
                          ),
                        ),
                        const SizedBox(height: HomeMetrics.artistNameGap),
                        SizedBox(
                          width: HomeMetrics.artistAvatarSize * 0.7,
                          height: nameHeight,
                          child: const SkeletonBox(
                            radius: HomeMetrics.badgeRadius,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
