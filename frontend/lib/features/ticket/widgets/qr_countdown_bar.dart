import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// QR 이 만료되기까지 남은 시간. 숫자와 진행 바로 함께 보여주고, 화면 읽기
/// 프로그램에는 남은 초를 읽어 준다. [TicketMetrics.qrWarningThreshold] 안쪽이면
/// 경고색으로 바꾸고 만료된 뒤(0)에도 유지한다 — 읽는 도중 만료되기 전에 알린다.
class QrCountdownBar extends StatelessWidget {
  const QrCountdownBar({
    super.key,
    required this.remaining,
    required this.progress,
  });

  final Duration remaining;

  /// 남은 비율 0~1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = formatCountdown(remaining);
    final urgent = remaining <= TicketMetrics.qrWarningThreshold;

    return Semantics(
      label: TicketStrings.qrRemainingSemantics(remaining.inSeconds),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TicketStrings.qrRemaining,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: urgent ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                urgent ? AppColors.accent : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
