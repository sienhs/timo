import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// QR 이 만료되기까지 남은 시간. 숫자와 진행 바로 함께 보여준다.
///
/// 진행 바만 두지 않는 이유는 줄어드는 막대만으로는 몇 초 남았는지 알 수 없고,
/// 색 대비에 기대는 표시라 잘 안 보이는 사람에게 아무 정보도 주지 않아서다.
/// 화면 읽기 프로그램에도 남은 초를 그대로 읽어 준다.
///
/// 남은 시간이 [TicketMetrics.qrWarningThreshold] 안쪽이면 숫자와 막대를
/// 경고색으로 바꾼다(사용자 결정, 2026-09-20). 검표기 앞에서 마지막 몇 초에
/// QR 을 내밀면 읽는 도중 만료돼 다시 받아야 한다 — 그 전에 눈에 띄게 알린다.
/// 만료된 뒤(0)에도 경고색을 유지한다. 색만으로 알리지는 않는다. 숫자가 함께
/// 있고, 만료되면 QR 위에 새로고침 버튼과 문구가 따로 뜬다.
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
