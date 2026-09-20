import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/concert_summary.dart';

/// 공연 목록 한 줄. 포스터 · 공연명 · 공연장 · 일시.
///
/// 오늘 하는 공연이면 공연명 위에 '오늘' 뱃지가 붙는다([isToday]). 오늘인지를
/// 여기서 계산하지 않고 받는 이유: 목록 전체가 같은 "지금" 을 기준으로 판단해야
/// 하는데, 줄마다 `DateTime.now()` 를 부르면 자정을 넘기는 순간 줄마다 다른
/// 답이 나온다. 정렬도 같은 기준을 쓴다.
class ConcertTile extends StatelessWidget {
  const ConcertTile({
    super.key,
    required this.concert,
    required this.isToday,
    required this.onPressed,
  });

  final ConcertSummary concert;
  final bool isToday;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final when = concert.whenLabel;

    return Semantics(
      button: true,
      label: ConcertStrings.tileSemantics(
        concert.title,
        concert.venueName,
        when,
      ),
      // 줄 전체를 한 문장으로 읽어 주므로 안쪽 글자는 따로 읽지 않는다.
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ConcertMetrics.tileMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.pagePadding,
              vertical: 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: ConcertMetrics.posterWidth,
                  child: AspectRatio(
                    aspectRatio: ConcertMetrics.posterAspectRatio,
                    child: PosterImage.network(
                      url: concert.posterImageUrl,
                      borderRadius: ConcertMetrics.posterRadius,
                      decodeWidth: ConcertMetrics.posterWidth,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isToday) ...[
                        const _TodayBadge(),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        concert.title,
                        style: textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        concert.venueName,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        when,
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppMetrics.inlineGap),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘 하는 공연 표시. 목록에서 눈이 먼저 가야 하는 단 하나의 표식이라
/// 브랜드색을 채워 쓴다.
///
/// 흰 글자를 올리므로 [AppColors.primary] 가 아니라 [AppColors.primaryPressed]
/// 다 — 브랜드 그린 위의 흰 글자는 대비가 3.43:1 이라 이만큼 작은 글자에
/// 쓸 수 없다.
class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryPressed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ConcertStrings.today,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.onPrimary),
      ),
    );
  }
}
