import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 목록이 빈 자리. 시안에는 없다.
///
/// 탭마다 할 말이 다르다. "예정된 공연이 없어요" 와 "등록한 양도 매물이
/// 없어요" 는 사용자가 다음에 할 일이 다르므로 문구를 나눠 받는다. 예정 탭만
/// 갈 곳(공연 목록)이 있어 버튼을 단다.
class TicketEmptyView extends StatelessWidget {
  const TicketEmptyView({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TicketMetrics.horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              size: 48,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
