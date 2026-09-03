import 'package:flutter/material.dart';

import '../constants.dart';
import '../../../core/utils/formatters.dart';
import '../models/ticket_order.dart';
import 'order_info_row.dart';
import 'payment_card.dart';

/// 완료 화면의 예약 정보 요약 카드.
class BookingDetailCard extends StatelessWidget {
  const BookingDetailCard({super.key, required this.order});

  final TicketOrder order;

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
          OrderInfoRow(
            label: PaymentConstants.seatLabel,
            value: order.seat,
          ),
          OrderInfoRow(
            label: PaymentConstants.paidAmountLabel,
            value: formatWon(order.totalPrice),
            valueColor: PaymentColors.total,
          ),
        ],
      ),
    );
  }
}
