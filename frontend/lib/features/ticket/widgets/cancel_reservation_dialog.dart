import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import 'ticket_confirm_dialog.dart';

/// 예매 취소 확인 팝업. 무엇을 취소하는지(공연·좌석)와 얼마가 돌아오는지를 함께
/// 보여준다. 틀과 버튼은 [showTicketConfirmDialog] 가 정한다. 취소하면 true.
Future<bool> showCancelReservationDialog(
  BuildContext context, {
  required MyTicket ticket,
}) => showTicketConfirmDialog(
  context,
  title: TicketStrings.cancelConfirmTitle,
  summary: (
    title: ticket.title,
    seat: ticket.seatLabel,
    // 원이 아니라 MSR 이다. 결제도 환불도 코인으로 오간다.
    amount: TicketStrings.refundAmount(formatMsr(ticket.facePrice)),
  ),
  body: TicketStrings.cancelConfirmBody,
  agreeLabel: TicketStrings.cancelConfirmAgree,
);
