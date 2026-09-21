import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/concert_summary.dart';

/// 공연 목록 카드 한 장. 포스터 · 뱃지 · 공연명 · 공연장 · 일시.
///
/// 오늘 하는 공연이면 카드 바탕과 테두리가 브랜드색으로 바뀌고 '오늘' 뱃지가
/// 붙는다([isToday]). 지금 입장을 받고 있으면 '입장 진행 중' 뱃지가 하나 더
/// 붙는다([isEntryOpen]) — 오늘 공연이라도 문 열기 전에는 안 붙는다.
///
/// 두 판정을 여기서 계산하지 않고 받는 이유: 목록 전체가 같은 "지금" 을 기준으로
/// 판단해야 하는데, 카드마다 `DateTime.now()` 를 부르면 자정을 넘기는 순간
/// 카드마다 다른 답이 나온다. 정렬·필터 칩도 같은 기준을 쓴다.
class ConcertTile extends StatelessWidget {
  const ConcertTile({
    super.key,
    required this.concert,
    required this.isToday,
    required this.isEntryOpen,
    required this.onPressed,
  });

  final ConcertSummary concert;
  final bool isToday;
  final bool isEntryOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final when = concert.whenLabel;
    final radius = BorderRadius.circular(ConcertMetrics.cardRadius);

    return Semantics(
      button: true,
      label: _semanticsLabel(when),
      // 카드를 한 문장으로 읽어 주므로 안쪽 글자는 따로 읽지 않는다.
      excludeSemantics: true,
      child: Material(
        color: isToday ? AppColors.primarySoft : AppColors.surface,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: ConcertMetrics.tileMinHeight,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: isToday
                    ? AppColors.primarySoftBorder
                    : AppColors.border,
                width: ConcertMetrics.cardBorderWidth,
              ),
            ),
            padding: const EdgeInsets.all(ConcertMetrics.cardPadding),
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
                      if (isToday || isEntryOpen) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isToday) const _TodayBadge(),
                            if (isEntryOpen) const _EntryOpenBadge(),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        concert.title,
                        style: textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _IconLine(
                        icon: Icons.place_outlined,
                        text: concert.venueName,
                      ),
                      const SizedBox(height: 2),
                      _IconLine(icon: Icons.schedule_rounded, text: when),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
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

  /// 뱃지도 한 문장에 넣는다. 뱃지가 색으로만 구분되면 화면 읽기 프로그램을
  /// 쓰는 운영자에게는 없는 것과 같다.
  String _semanticsLabel(String when) {
    final badges = [
      if (isToday) ConcertStrings.today,
      if (isEntryOpen) ConcertStrings.entryOpen,
    ];
    final tile = ConcertStrings.tileSemantics(
      concert.title,
      concert.venueName,
      when,
    );
    return badges.isEmpty ? tile : '${badges.join('. ')}. $tile';
  }
}

/// 공연장·일시 한 줄. 아이콘이 앞에 붙어 두 줄이 서로 구분된다 — 글자만
/// 두 줄이면 공연장 이름이 짧을 때 어느 줄이 무엇인지 한눈에 안 갈린다.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textDisabled),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 오늘 하는 공연 표시. 목록에서 눈이 먼저 가야 하는 표식이라 브랜드색을
/// 채워 쓴다.
///
/// 흰 글자를 올리므로 [AppColors.primary] 가 아니라 [AppColors.primaryPressed]
/// 다 — 브랜드 그린 위의 흰 글자는 대비가 3.43:1 이라 이만큼 작은 글자에
/// 쓸 수 없다.
class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return _Badge(
      label: ConcertStrings.today,
      background: AppColors.primaryPressed,
      foreground: AppColors.onPrimary,
    );
  }
}

/// 지금 입장을 받고 있는 공연 표시. '오늘' 옆에 나란히 붙으므로 채우지 않고
/// 테두리만 둘러, 둘 중 먼저 읽혀야 하는 쪽이 '오늘' 로 남게 한다.
class _EntryOpenBadge extends StatelessWidget {
  const _EntryOpenBadge();

  @override
  Widget build(BuildContext context) {
    return _Badge(
      label: ConcertStrings.entryOpen,
      background: AppColors.surface,
      foreground: AppColors.primaryPressed,
      border: AppColors.primarySoftBorder,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final outline = border;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: outline == null ? null : Border.all(color: outline),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
