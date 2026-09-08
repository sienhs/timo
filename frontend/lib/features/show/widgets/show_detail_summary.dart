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
        ShowStatusBadge(isOpen: isOpen),
        const SizedBox(height: ShowDetailMetrics.summaryLineGap),
        Text(detail.title, style: textTheme.headlineSmall),
        const SizedBox(height: ShowDetailMetrics.summaryLineGap),
        Text(ShowDetailStrings.venueLine(detail.venue), style: lineStyle),
        Text(
          ShowDetailStrings.periodLine(detail.periodLabel),
          style: lineStyle,
        ),
      ],
    );
  }
}
