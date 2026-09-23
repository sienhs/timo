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
    required this.phase,
  });

  final ShowDetail detail;

  /// 이 공연이 지금 어느 단계인지. 화면이 기준 시각으로 판정해 하단 바와 **같은 값**을
  /// 넘긴다 — 뱃지가 따로 판정하면 '예매중' 뱃지 밑에 잠긴 버튼이 붙는다.
  final ShowBookingPhase phase;

  /// 상태 뱃지를 달 단계인지. `default` 도 `_` 도 두지 않는 이유는 하단 바의
  /// `_lockedLabel` 과 같다 - 단계가 늘었을 때 조용히 통과하는 대신 컴파일이 깨지게 둔다.
  bool get _showsBadge => switch (phase) {
    ShowBookingPhase.onSale ||
    ShowBookingPhase.upcoming ||
    ShowBookingPhase.awaitingOpen => true,
    ShowBookingPhase.bookingClosed ||
    ShowBookingPhase.finished ||
    ShowBookingPhase.canceled => false,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lineStyle = textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 하단 바가 버튼을 잠그는 공연에는 뱃지를 달지 않는다. 마감·종료·취소는 시각만
        // 보면 '예매중' 이 되는데, 살 수 없는 공연에 그 말이 붙으면 거짓말이 된다.
        if (_showsBadge) ...[
          ShowStatusBadge(isOpen: phase == ShowBookingPhase.onSale),
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
