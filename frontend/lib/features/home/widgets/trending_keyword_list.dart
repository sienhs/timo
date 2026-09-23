import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/trending_keyword.dart';

/// 실시간 인기 검색어. 제목 · 집계 시각 한 줄 아래 순위 목록이다. 줄을 누르면
/// 그 검색어로 검색한다. 등락은 아이콘 + 색 + 시맨틱 라벨 세트라 색을 못 봐도 안다.
class TrendingKeywordList extends StatelessWidget {
  const TrendingKeywordList({
    super.key,
    required this.trending,
    required this.onKeywordPressed,
  });

  final TrendingKeywords trending;
  final ValueChanged<String> onKeywordPressed;

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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  HomeStrings.trendingSection,
                  style: textTheme.titleMedium,
                ),
              ),
              Text(
                HomeStrings.trendingAsOf(trending.asOf),
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        for (final item in trending.items)
          _TrendingRow(
            item: item,
            onPressed: () => onKeywordPressed(item.keyword),
          ),
      ],
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.item, required this.onPressed});

  final TrendingKeyword item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isHighlighted = item.rank <= HomeMetrics.trendingHighlightRanks;
    return Semantics(
      button: true,
      label: HomeStrings.searchFor(item.keyword),
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: HomeMetrics.trendingRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.horizontalPadding,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: HomeMetrics.trendingRankWidth,
                  child: Text(
                    '${item.rank}',
                    style: textTheme.titleSmall?.copyWith(
                      color: isHighlighted
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.keyword,
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _TrendIcon(trend: item.trend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 등락 표시. 변동이 없으면 자리만 지킨다 — 아이콘이 있는 줄과 없는 줄의
/// 검색어 끝이 들쭉날쭉해지지 않게.
class _TrendIcon extends StatelessWidget {
  const _TrendIcon({required this.trend});

  final KeywordTrend trend;

  @override
  Widget build(BuildContext context) {
    return switch (trend) {
      KeywordTrend.up => const Icon(
        Icons.arrow_drop_up,
        size: HomeMetrics.trendingChangeIconSize,
        color: AppColors.accent,
        semanticLabel: HomeStrings.trendingUp,
      ),
      KeywordTrend.down => const Icon(
        Icons.arrow_drop_down,
        size: HomeMetrics.trendingChangeIconSize,
        color: AppColors.brand,
        semanticLabel: HomeStrings.trendingDown,
      ),
      KeywordTrend.steady => const SizedBox(
        width: HomeMetrics.trendingChangeIconSize,
      ),
    };
  }
}
