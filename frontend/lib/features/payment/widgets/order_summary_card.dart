import 'package:flutter/material.dart';

import '../constants.dart';
import '../formatters.dart';
import '../models/ticket_order.dart';
import 'order_info_row.dart';
import 'payment_card.dart';
import 'poster_thumbnail.dart';

/// 결제 화면의 주문 요약 카드. 공연 정보 + 금액 내역 + 최종 합계를 보여준다.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({super.key, required this.order});

  final TicketOrder order;

  @override
  Widget build(BuildContext context) {
    return PaymentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConcertHeader(order: order),
          const SizedBox(height: 18),
          const _CardDivider(),
          OrderInfoRow(
            label: PaymentConstants.bookerLabel,
            value: order.bookerName,
          ),
          OrderInfoRow(
            label: PaymentConstants.ticketPriceLabel,
            value: formatWon(order.ticketPrice),
            valueColor: PaymentColors.price,
          ),
          OrderInfoRow(
            label: PaymentConstants.bookingFeeLabel,
            value: formatWon(order.bookingFee),
            valueColor: PaymentColors.price,
          ),
          const _CardDivider(),
          _TotalRow(total: order.totalPrice),
        ],
      ),
    );
  }
}

/// 포스터와 공연 기본 정보(제목·일시·장소·좌석).
class _ConcertHeader extends StatelessWidget {
  const _ConcertHeader({required this.order});

  final TicketOrder order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.concertTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PaymentColors.value,
                ),
              ),
              const SizedBox(height: 10),
              _MetaLine(formatPerformedAt(order.performedAt, separator: '/')),
              _MetaLine(order.venue),
              _MetaLine(order.seat),
            ],
          ),
        ),
        const SizedBox(width: 12),
        PosterThumbnail(assetPath: order.posterAsset),
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: PaymentColors.label),
      ),
    );
  }
}

/// 최종 결제 금액. 다른 행보다 크고 강조색을 쓴다.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Text(
            PaymentConstants.totalLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: PaymentColors.value,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatWon(total),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: PaymentColors.total,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(height: 1, thickness: 1, color: PaymentColors.divider),
    );
  }
}
