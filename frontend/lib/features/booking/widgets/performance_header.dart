import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/performance.dart';

/// 좌석 선택 화면 상단의 공연 정보 바.
///
/// 시안 보강: 좌석 선택 두 화면에는 공연 정보가 없어서, 어떤 공연을
/// 예매 중인지 결제 화면에 가서야 알 수 있었다. 한 줄만 얇게 붙였다.
class PerformanceHeader extends StatelessWidget {
  const PerformanceHeader({super.key, required this.performance});

  final Performance performance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            performance.title,
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${formatPerformedAtWithWeekday(performance.startAt)} '
            '· ${performance.venue}',
            style: textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
