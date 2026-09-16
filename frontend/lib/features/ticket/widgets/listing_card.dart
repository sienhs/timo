import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../resale/models/my_trade.dart';
import '../constants.dart';
import 'ticket_badge.dart';
import 'ticket_card.dart';
import 'ticket_card_header.dart';

/// 양도 목록 카드. 내가 마켓에 올린 매물 하나다.
///
/// 시안대로 공연장 줄이 없다. 내가 올린 내 티켓이라 어디서 하는 공연인지는
/// 이미 아는 정보고, 대신 등록가와 마감이 그 자리를 쓴다.
///
/// 아래쪽은 매물 상태가 정한다.
///
/// | 상태 | 배지 | 아래쪽 |
/// | --- | --- | --- |
/// | 판매중 | `판매중` | 등록가 · 마감, `가격 수정` + `등록 취소` |
/// | 팔림 | `판매 완료` | 등록가, "판매가 완료됐어요" 안내 |
/// | 내림 | 없음(회색 카드) | 등록가, "등록을 취소했어요" 안내 |
///
/// 시안에는 판매중만 있다. 팔린 것과 내린 것도 서버가 같은 목록으로 주는데,
/// 지우면 결과가 안 보인다 — 예매 취소한 티켓을 회색 카드로 남기는 것과 같은
/// 판단이다.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.trade,
    required this.now,
    required this.onEditPrice,
    required this.onDelist,
  });

  /// 내가 올린 매물. [MyTrade.isSale] 인 항목만 온다.
  final MyTrade trade;

  /// 지금 시각. 화면이 한 번 정해 모든 카드에 같은 값을 준다 — 카드마다
  /// `DateTime.now()` 를 부르면 목록 안에서 마감 기준이 미세하게 갈린다.
  final DateTime now;

  final VoidCallback onEditPrice;
  final VoidCallback onDelist;

  @override
  Widget build(BuildContext context) {
    final delisted = trade.status == MyTradeStatus.canceled;

    return TicketCard(
      child: Column(
        children: [
          TicketCardHeader(
            title: trade.concertTitle,
            posterImageUrl: trade.posterImageUrl,
            dimmed: delisted,
            badge: _badge(),
            infoLines: [
              (
                icon: Icons.calendar_today_outlined,
                text: trade.startAt == null
                    ? TicketStrings.dateUndecided
                    : formatPerformedAt(trade.startAt!),
              ),
              (icon: Icons.event_seat_outlined, text: trade.seatLabel),
            ],
          ),
          const SizedBox(height: TicketMetrics.cardPadding),
          _PriceRow(trade: trade, now: now),
          const SizedBox(height: 10),
          _footer(),
        ],
      ),
    );
  }

  /// 내린 매물에는 배지를 안 붙인다. 회색 카드와 아래 안내가 이미 말해 준다.
  Widget? _badge() => switch (trade.status) {
    MyTradeStatus.listed => const TicketBadge(
      label: TicketStrings.listingBadge,
    ),
    MyTradeStatus.sold => const TicketBadge(label: TicketStrings.soldBadge),
    _ => null,
  };

  Widget _footer() => switch (trade.status) {
    MyTradeStatus.listed => Row(
      children: [
        Expanded(
          child: TicketCardButton(
            label: TicketStrings.editPrice,
            onPressed: onEditPrice,
            filled: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TicketCardButton(
            label: TicketStrings.delist,
            onPressed: onDelist,
          ),
        ),
      ],
    ),
    MyTradeStatus.sold => const TicketCardNotice(
      text: TicketStrings.soldNotice,
      icon: Icons.check_circle_outline,
    ),
    MyTradeStatus.canceled => const TicketCardNotice(
      text: TicketStrings.delistedNotice,
      icon: Icons.block_outlined,
    ),
    // 판매에 오지 않을 값(구매 상태)이거나 앱이 모르는 상태. 무슨 일인지
    // 단정하지 않고, 지금 할 수 있는 게 없다는 것만 말한다.
    _ => const TicketCardNotice(
      text: TicketStrings.unknownStatusNotice,
      icon: Icons.help_outline,
    ),
  };
}

/// 등록가(왼쪽)와 마감(오른쪽) 한 줄. 마감은 아직 팔리는 매물에만 뜻이 있어
/// 그때만 찍는다.
class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.trade, required this.now});

  final MyTrade trade;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          TicketStrings.listedPrice(formatMsr(trade.price)),
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (trade.isOnSale)
          Flexible(
            child: Text(
              _deadlineLabel(),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  /// 하루 안쪽이면 카운트다운, 그 이상이면 마감 일시.
  String _deadlineLabel() {
    final remaining = trade.remaining(now);
    if (remaining == null) {
      // 공연이 이미 시작했거나 일정이 미정이다. 어느 쪽이든 더 팔 수 없다.
      return TicketStrings.deadlinePassed;
    }
    if (remaining.inDays >= 1) {
      return TicketStrings.deadlineAt(formatPerformedAt(trade.startAt!));
    }
    return TicketStrings.deadlineIn(remaining);
  }
}
