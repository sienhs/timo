import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import '../models/ticket_status.dart';
import 'ticket_badge.dart';
import 'ticket_card.dart';
import 'ticket_card_header.dart';

/// 예정 공연 카드.
///
/// 아래쪽에 무엇이 오는지는 티켓 상태와 공연 시각이 정한다.
///
/// | 상태 | 아래쪽 |
/// | --- | --- |
/// | 발행 중 | "티켓을 만들고 있어요" 안내 |
/// | 발행 실패 | "환불이 진행 중이에요" 안내 |
/// | 환불·취소됨 | 회색 카드 + 결과 안내 |
/// | 정상 · 공연 시간대 | `입장 QR 보기` (꽉 찬 초록) |
/// | 정상 · 그 밖 | `상세정보 보기` + 언제 QR 이 열리는지 한 줄 |
///
/// 시안에는 위 셋(발행 중·실패·회수)이 없다. 결제 직후에는 티켓이 아직 안 나와
/// 입장도 양도도 안 되는데 그 사정을 알릴 자리가 없었다.
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
  final VoidCallback onShowDetail;

  /// 더보기(⋮). 지금은 예매 취소 하나가 들어간다. null 이면 안 그린다.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final voided = ticket.status.isVoided;
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

  /// 남은 날 배지.
  ///
  /// 회수된 티켓에는 붙이지 않는다. 이미 못 가는 공연이라 남은 날을 세는 게
  /// 의미가 없다.
  Widget? _badge(int? days) {
    if (ticket.status.isVoided) return null;
    if (days == null || days < 0) return null;
    return TicketBadge(label: TicketStrings.dday(days));
  }

  Widget _footer(BuildContext context) {
    final status = ticket.status;
    if (status == TicketStatus.cancelled) {
      return const TicketCardNotice(
        text: TicketStrings.cancelledNotice,
        icon: Icons.block_outlined,
      );
    }
    if (status == TicketStatus.unknown) {
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
          TicketStrings.qrOpensOnShowDay,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
