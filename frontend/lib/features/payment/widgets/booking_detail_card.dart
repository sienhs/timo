import 'package:flutter/material.dart';

import '../constants.dart';
import '../../../core/utils/formatters.dart';
import '../models/ticket_order.dart';
import 'order_info_row.dart';
import 'payment_card.dart';

/// 완료 화면의 예약 정보 요약 카드.
class BookingDetailCard extends StatelessWidget {
  const BookingDetailCard({
    super.key,
    required this.order,
    this.refunding = false,
  });

  final TicketOrder order;

  /// 발행이 실패해 서버가 결제 금액을 되돌리는 중인가.
  ///
  /// 참이면 마지막 줄이 '결제 금액' 이 아니라 '환불 예정 금액' 이 된다. 금액
  /// 자체는 그대로다 — 되돌려 주는 액수가 낸 액수와 같다.
  final bool refunding;

  @override
  Widget build(BuildContext context) {
    return PaymentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderInfoRow(
            label: PaymentConstants.concertLabel,
            value: order.concertTitle,
          ),
          OrderInfoRow(
            label: PaymentConstants.performedAtLabel,
            value: formatPerformedAt(order.performedAt),
          ),
          OrderInfoRow(label: PaymentConstants.seatLabel, value: order.seat),
          OrderInfoRow(
            label: refunding
                ? PaymentConstants.refundAmountLabel
                : PaymentConstants.paidAmountLabel,
            value: formatWon(order.ticketPrice),
            valueColor: refunding ? PaymentColors.value : PaymentColors.total,
          ),
        ],
      ),
    );
  }
}
