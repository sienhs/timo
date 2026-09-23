import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import '../models/ticket_status.dart';
import 'ticket_badge.dart';
import 'ticket_card.dart';
import 'ticket_card_header.dart';

/// 예정 공연 카드. 아래쪽은 티켓 상태와 공연 시각이 정한다 — 보유면 공연
/// 시간대에 `입장 QR 보기`, 그 밖에는 `상세정보 보기` + QR 이 열리는 시각 한 줄,
/// 양도 등록 중·발행 중·실패·환불·회수·입장 완료·모르는 상태는 버튼 대신 안내다.
/// 서버가 거절할 일은 눌러 보게 하지 않고 여기서 잠근다.
class UpcomingTicketCard extends StatelessWidget {
  const UpcomingTicketCard({
    super.key,
    required this.ticket,
    required this.now,
    required this.onEnterQr,
    required this.onShowDetail,
    this.onMore,
  });

  final MyTicket ticket;

  /// 지금 시각. 화면이 한 번 정해 모든 카드에 같은 값을 준다 — 카드마다
  /// `DateTime.now()` 를 부르면 목록 안에서 D-day 기준이 미세하게 갈린다.
  final DateTime now;

  final VoidCallback onEnterQr;

  /// 이 티켓의 공연 상세로 간다. QR 이 아직 안 열린 카드에만 붙는다 — 열린
  /// 카드에서는 입장이 할 일이라 그 자리를 QR 이 가져간다.
  final VoidCallback onShowDetail;

  /// 더보기(⋮). 양도 등록과 예매 취소가 들어간다. null 이면 안 그린다.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final voided = ticket.isVoided;
    final days = ticket.daysUntil(now);

    return TicketCard(
      child: Column(
        children: [
          TicketCardHeader(
            title: ticket.title,
            posterImageUrl: ticket.posterImageUrl,
            dimmed: voided,
            badge: _badge(days),
            // 제목 줄 높이에 맞춰 상자를 고정한다. 버튼이 스스로 커지면 이
            // 카드만 제목과 정보 줄 사이가 벌어져 옆 카드와 눈높이가 어긋난다.
            trailing: onMore == null
                ? null
                : SizedBox(
                    width: 28,
                    height: 24,
                    child: IconButton(
                      onPressed: onMore,
                      icon: const Icon(Icons.more_vert),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: TicketStrings.more,
                    ),
                  ),
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
          _footer(context),
        ],
      ),
    );
  }

  /// 왼쪽 위 배지. 발행 중이면 남은 날 대신 `NFT 발행 중` 이고, 회수·환불된
  /// 티켓에는 아무것도 붙이지 않는다 — 못 가는 공연이라 남은 날이 의미 없다.
  Widget? _badge(int? days) {
    if (ticket.status == TicketStatus.pendingMint) {
      return const TicketBadge(label: TicketStrings.issuingBadge);
    }
    if (ticket.isVoided) return null;
    if (days == null || days < 0) return null;
    return TicketBadge(label: TicketStrings.dday(days));
  }

  /// 아래쪽. 끝난 상태(회수·환불·입장 완료)를 먼저 보고, 그다음 진행 중(발행·
  /// 등록), 마지막에 보유다. 양도 등록 중은 상태값이 아니라 [MyTicket.isListed] 로 본다.
  Widget _footer(BuildContext context) {
    switch (ticket.status) {
      case TicketStatus.revoked:
        return const TicketCardNotice(
          text: TicketStrings.cancelledNotice,
          icon: Icons.block_outlined,
        );
      case TicketStatus.refunded:
        return const TicketCardNotice(
          text: TicketStrings.refundedNotice,
          icon: Icons.block_outlined,
        );
      case TicketStatus.used:
        return const TicketCardNotice(
          text: TicketStrings.usedNotice,
          icon: Icons.check_circle_outline,
        );
      case TicketStatus.mintFailed:
        return const TicketCardNotice(
          text: TicketStrings.mintFailedNotice,
          icon: Icons.error_outline,
        );
      case TicketStatus.pendingMint:
        return const TicketCardNotice(
          text: TicketStrings.issuingNotice,
          icon: Icons.hourglass_top_outlined,
        );
      case TicketStatus.owned:
      case TicketStatus.listed:
      case TicketStatus.unknown:
        break;
    }
    if (ticket.isListed) {
      return const TicketCardNotice(
        text: TicketStrings.listedNotice,
        icon: Icons.storefront_outlined,
      );
    }
    if (!ticket.isUsable) {
      return const TicketCardNotice(
        text: TicketStrings.unknownStatusNotice,
        icon: Icons.help_outline,
      );
    }
    if (ticket.canEnter(now)) {
      return TicketCardButton(
        label: TicketStrings.enterQr,
        onPressed: onEnterQr,
        filled: true,
      );
    }
    return Column(
      children: [
        TicketCardButton(
          label: TicketStrings.showDetail,
          onPressed: onShowDetail,
        ),
        const SizedBox(height: 8),
        Text(
          TicketStrings.qrOpensBeforeShow,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
