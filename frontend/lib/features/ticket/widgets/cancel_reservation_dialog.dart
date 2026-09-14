import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/my_ticket.dart';

/// 예매 취소 확인 팝업.
///
/// 취소는 되돌릴 수 없고 같은 자리를 다시 잡을 수도 없으므로 한 번 묻는다.
/// 무엇을 취소하는지(공연·좌석)와 얼마가 돌아오는지를 함께 보여준다 — "정말
/// 취소할까요?" 만 띄우면 어느 티켓인지 모른 채 누르게 된다.
///
/// 모양은 아이디 확정 팝업과 같은 얇은 테두리다. 다만 되돌릴 수 없는
/// 행동이라 테두리와 확인 버튼을 강조색(코랄)으로 둔다.
///
/// 취소하기로 했으면 true, 아니면 false.
Future<bool> showCancelReservationDialog(
  BuildContext context, {
  required MyTicket ticket,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CancelReservationDialog(ticket: ticket),
  );
  return confirmed ?? false;
}

class _CancelReservationDialog extends StatelessWidget {
  const _CancelReservationDialog({required this.ticket});

  final MyTicket ticket;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      // Material 의 shape.side 로는 테두리가 그려지지 않아 배경을 비우고
      // 테두리를 직접 그린다. 아이디 확정 팝업과 같은 이유다.
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: AppColors.accent),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              TicketStrings.cancelConfirmTitle,
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            _TicketSummary(ticket: ticket),
            const SizedBox(height: 12),
            Text(
              TicketStrings.cancelConfirmBody,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                backgroundColor: AppColors.accent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(TicketStrings.cancelConfirmAgree),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(TicketStrings.cancelConfirmKeep),
            ),
          ],
        ),
      ),
    );
  }
}

/// 무엇을 취소하는지. 공연명·좌석과 돌아올 금액.
class _TicketSummary extends StatelessWidget {
  const _TicketSummary({required this.ticket});

  final MyTicket ticket;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Text(
            ticket.title,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.seatLabel,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TicketStrings.refundAmount(formatWon(ticket.facePrice)),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryPressed,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
