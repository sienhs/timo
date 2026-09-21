import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/server_status.dart';

/// 헤더 맨 위의 서버 상태 칩. 점 하나와 글자 한 마디.
///
/// 점 색과 글자를 항상 함께 바꾼다 — 초록·빨강만으로 구분하면 색약 운영자와
/// 햇빛 아래에서 읽을 수 없다.
class ServerStatusChip extends StatelessWidget {
  const ServerStatusChip({super.key, required this.status});

  final ServerStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.scanPanel,
        borderRadius: BorderRadius.circular(ScanMetrics.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: ScanMetrics.statusDotSize,
            height: ScanMetrics.statusDotSize,
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: textTheme.labelSmall?.copyWith(color: AppColors.onScan),
          ),
        ],
      ),
    );
  }

  Color get _dotColor => switch (status) {
    ServerStatus.unknown => AppColors.textDisabled,
    ServerStatus.online => AppColors.primary,
    ServerStatus.offline => AppColors.accent,
  };
}
