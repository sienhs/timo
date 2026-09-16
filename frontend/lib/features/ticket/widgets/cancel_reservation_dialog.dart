import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_dialog_frame.dart';
import '../constants.dart';
import '../models/my_ticket.dart';

/// 예매 취소 확인 팝업.
///
/// 취소는 되돌릴 수 없고 같은 자리를 다시 잡을 수도 없으므로 한 번 묻는다.
/// 무엇을 취소하는지(공연·좌석)와 얼마가 돌아오는지를 함께 보여준다 — "정말
/// 취소할까요?" 만 띄우면 어느 티켓인지 모른 채 누르게 된다.
///
/// 틀은 다른 팝업과 같되 테두리는 없다(사용자 결정). 되돌릴 수 없는 행동임은
/// 확인 버튼의 강조색(코랄)으로만 알리고, '그대로 둘게요' 는 같은 크기의 흰
/// 바탕·초록 테두리 버튼으로 나란히 둔다. 금액은 원이 아니라 코인(MSR)이다.
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

    // 모서리·여백은 앱 팝업 공통([AppDialogFrame])을 따르되 테두리는 그리지
    // 않는다(사용자 결정). 되돌릴 수 없는 행동임은 확인 버튼의 강조색으로만 알린다.
    return AppDialogFrame(
      borderColor: null,
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
          // 안내문이 한 줄이 되면서 20 은 아래가 비어 보였다(사용자 피드백).
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.accent,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(TicketStrings.cancelConfirmAgree),
          ),
          const SizedBox(height: 8),
          // 취소 버튼과 같은 크기의 흰 바탕·초록 테두리 버튼(사용자 결정). 글자만
          // 있는 버튼이면 두 선택지의 무게가 달라 보인다.
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text(TicketStrings.cancelConfirmKeep),
          ),
        ],
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
            // 원이 아니라 MSR 이다(사용자 결정). 결제도 환불도 코인으로 오간다.
            TicketStrings.refundAmount(formatMsr(ticket.facePrice)),
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
