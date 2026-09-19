import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_action_button.dart';
import '../constants.dart';

/// 티켓 카드 한 장의 껍데기. 흰 바탕, 테두리, 둥근 모서리.
///
/// 예정·지난·양도 카드가 같은 상자 안에 들어간다. 상자 모양을 카드마다 적으면
/// 테두리 색이나 모서리 반경이 조금씩 갈린다.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: TicketMetrics.cardGap),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(TicketMetrics.cardRadius),
      ),
      padding: const EdgeInsets.all(TicketMetrics.cardPadding),
      child: child,
    );
  }
}

/// 카드 아래쪽 버튼 한 개. 시안의 꽉 찬 초록 버튼과 테두리 버튼 두 가지다.
class TicketCardButton extends StatelessWidget {
  const TicketCardButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;

  /// null 이면 눌리지 않는다.
  final VoidCallback? onPressed;

  /// 꽉 찬 초록 버튼인지. 카드에서 가장 중요한 행동 하나에만 쓴다.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AppActionButton(
      label: label,
      onPressed: onPressed,
      compact: true,
      variant: filled ? AppActionStyle.primary : AppActionStyle.secondary,
    );
  }
}

/// 버튼 대신 들어가는 안내 줄. 발행 중·실패·취소처럼 지금 할 수 있는 일이
/// 없을 때 그 이유를 적는다.
class TicketCardNotice extends StatelessWidget {
  const TicketCardNotice({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
