import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';
import 'show_card_list_skeleton.dart';

/// 공연 목록 화면을 불러오는 동안 `ShowListView` 자리에 두는 뼈대. 검색 칸 ·
/// (있으면) 탭 줄 · 큰 카드 [HomeMetrics.skeletonCardCount] 장을 실제 목록과
/// 같은 높이와 간격으로 세워, 검색 칸이 사라졌다 되돌아오는 일이 없게 한다.
class ShowListSkeleton extends StatelessWidget {
  const ShowListSkeleton({super.key, this.hasTabs = false});

  /// 검색 칸 아래 탭 줄이 있는 화면인지(공연 전체 조회). 자리를 비워 두지
  /// 않으면 데이터가 오는 순간 카드가 탭 높이만큼 아래로 밀린다.
  final bool hasTabs;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: HomeStrings.loading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              HomeMetrics.horizontalPadding,
              HomeMetrics.searchFieldTopGap,
              HomeMetrics.horizontalPadding,
              0,
            ),
            child: SizedBox(
              height: HomeMetrics.searchFieldHeight,
              child: SkeletonBox(radius: HomeMetrics.searchFieldRadius),
            ),
          ),
          if (hasTabs) const _TabsPlaceholder(),
          const Expanded(
            child: SingleChildScrollView(
              // 뼈대를 굴려 볼 일은 없다. 스크롤 뷰로 감싸는 건 세로로 짧은
              // 기기에서 카드가 넘칠 때 화면이 깨지지 않게 하려는 것뿐이다.
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: HomeMetrics.sectionTitleGap),
              child: ShowCardListSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 탭 줄 자리. 글자 두 개와 아래 경계선까지 `UnderlineTabBar` 와 같은 높이다.
class _TabsPlaceholder extends StatelessWidget {
  const _TabsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final labelHeight = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: Padding(
                // 탭 글자 위아래 여백 + 밑줄 두께.
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
                child: Center(
                  child: SizedBox(
                    width: HomeMetrics.skeletonTabLabelWidth,
                    height: labelHeight,
                    child: const SkeletonBox(radius: HomeMetrics.badgeRadius),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
