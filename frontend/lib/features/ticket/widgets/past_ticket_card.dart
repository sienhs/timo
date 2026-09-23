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
    this.creating = false,
  });

  final MyTicket ticket;
  final VoidCallback onCreateCollectible;

  /// 소장품 제작 화면으로 갈 수 있는지 알아보는 중. 카탈로그를 받아 봐야
  /// 알 수 있어([MyTicket] 에는 입장 여부가 없다) 버튼에 잠깐 머문다.
  final bool creating;

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
            isBusy: creating,
          ),
        ],
      ),
    );
  }
}
