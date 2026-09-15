import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 최근 검색어 섹션. 제목 · '전체 삭제' 한 줄 아래 가로로 넘기는 칩 줄이다.
///
/// 비어 있을 때는 이 위젯을 쓰지 않는다 — 화면이 섹션 자체를 숨긴다. 그래서
/// 여기서는 빈 상태를 다루지 않는다.
class RecentSearchChips extends StatelessWidget {
  const RecentSearchChips({
    super.key,
    required this.keywords,
    required this.onKeywordPressed,
    required this.onRemovePressed,
    required this.onClearAllPressed,
  });

  /// 최신순.
  final List<String> keywords;
  final ValueChanged<String> onKeywordPressed;
  final ValueChanged<String> onRemovePressed;
  final VoidCallback onClearAllPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeMetrics.horizontalPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  HomeStrings.recentSection,
                  style: textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onClearAllPressed,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  textStyle: textTheme.bodySmall,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(HomeStrings.clearRecent),
              ),
            ],
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        SizedBox(
          height: HomeMetrics.recentChipHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.horizontalPadding,
            ),
            itemCount: keywords.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: HomeMetrics.recentChipGap),
            itemBuilder: (context, index) => _RecentChip(
              keyword: keywords[index],
              onPressed: () => onKeywordPressed(keywords[index]),
              onRemovePressed: () => onRemovePressed(keywords[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// 검색어 한 개. 본문을 누르면 검색, 끝의 X 를 누르면 삭제.
///
/// 두 동작이 한 칩에 있어 각각 따로 누를 수 있어야 한다. 그래서 칩 전체를
/// 하나의 버튼으로 만들지 않고 글자와 X 를 각자 눌리게 나눈다.
class _RecentChip extends StatelessWidget {
  const _RecentChip({
    required this.keyword,
    required this.onPressed,
    required this.onRemovePressed,
  });

  final String keyword;
  final VoidCallback onPressed;
  final VoidCallback onRemovePressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HomeMetrics.recentChipHeight / 2);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: HomeStrings.searchFor(keyword),
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: HomeMetrics.recentChipHorizontalPadding,
                  right: HomeMetrics.recentChipIconGap,
                ),
                child: Center(
                  child: Text(
                    keyword,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onRemovePressed,
            tooltip: HomeStrings.removeRecent(keyword),
            iconSize: HomeMetrics.recentChipIconSize,
            color: AppColors.textSecondary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: HomeMetrics.recentChipHeight,
              height: HomeMetrics.recentChipHeight,
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
