import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import 'ticket_card.dart';
import 'ticket_card_header.dart';

/// 지난 공연 카드.
///
/// 예정 카드와 달리 상태로 갈리는 부분이 없다. 이미 끝난 공연이라 입장도
/// 취소도 없고, 남는 일은 소장품을 만드는 것뿐이다. 회수된 티켓(환불·취소)은
/// 예정 탭에 남으므로 여기까지 오지 않는다.
class PastTicketCard extends StatelessWidget {
  const PastTicketCard({
    super.key,
    required this.ticket,
    required this.onCreateCollectible,
  });

  final MyTicket ticket;
  final VoidCallback onCreateCollectible;

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      child: Column(
        children: [
          TicketCardHeader(
            title: ticket.title,
            posterImageUrl: ticket.posterImageUrl,
            infoLines: [
              (
                icon: Icons.calendar_today_outlined,
                text: ticket.startAt == null
                    ? TicketStrings.dateUndecided
                    : formatPerformedAt(ticket.startAt!),
              ),
              (icon: Icons.place_outlined, text: ticket.venueName),
              (icon: Icons.event_seat_outlined, text: ticket.seatLabel),
            ],
          ),
          const SizedBox(height: TicketMetrics.cardPadding),
          TicketCardButton(
            label: TicketStrings.createCollectible,
            onPressed: onCreateCollectible,
          ),
        ],
      ),
    );
  }
}
