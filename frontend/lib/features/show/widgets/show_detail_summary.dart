import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_detail.dart';
import 'show_status_badge.dart';

/// 포스터 아래 제목 묶음 — 상태 뱃지 · 제목 · 공연 장소 · 일시.
class ShowDetailSummary extends StatelessWidget {
  const ShowDetailSummary({
    super.key,
    required this.detail,
    required this.isOpen,
  });

  final ShowDetail detail;

  /// 상태 뱃지가 무엇을 달지. 화면이 기준 시각으로 판정해서 넘긴다.
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineStyle = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 끝난 공연에는 뱃지를 달지 않는다. 오픈 시각은 이미 지났으니 판정만
        // 보면 '예매중' 이 되는데, 끝난 공연에 그 말이 붙으면 거짓말이 된다.
        // 대신 하단 바가 잠긴 버튼으로 끝난 공연임을 알린다.
        if (!detail.isFinished) ...[
          ShowStatusBadge(isOpen: isOpen),
          const SizedBox(height: ShowDetailMetrics.summaryLineGap),
        ],
        Text(detail.title, style: textTheme.headlineSmall),
        const SizedBox(height: ShowDetailMetrics.summaryLineGap),
        Text(ShowDetailStrings.venueLine(detail.venue), style: lineStyle),
        Text(
          ShowDetailStrings.periodLine(detail.dateTimeLabel),
          style: lineStyle,
        ),
      ],
    );
  }
}
