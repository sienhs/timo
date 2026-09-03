import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// 좌석 선택 화면 하단의 선택 좌석 · 결제 금액 바.
///
/// [seatLabel] 또는 [amount] 가 null 이면 아직 좌석을 고르지 않은 상태로
/// 보고 버튼을 잠근다. 시안에는 '선택 전' 상태가 없어서 여기서 정했다.
class BookingBottomBar extends StatelessWidget {
  const BookingBottomBar({
    super.key,
    required this.seatLabel,
    required this.amount,
    required this.actionLabel,
    required this.onPressed,
  });

  final String? seatLabel;
  final int? amount;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasSeat = seatLabel != null;
    // 필드는 널 승격이 안 되므로 지역 변수로 받는다.
    final amount = this.amount;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Field(
                      label: '선택한 좌석',
                      value: seatLabel ?? '좌석을 선택해주세요',
                      valueColor: hasSeat
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      textTheme: textTheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Field(
                    label: '결제 금액',
                    value: amount == null ? '-' : formatWon(amount),
                    alignEnd: true,
                    textTheme: textTheme,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.textTheme,
    this.valueColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(color: valueColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
