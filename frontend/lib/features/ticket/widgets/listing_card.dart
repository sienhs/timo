import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../resale/models/market_hours.dart';
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
/// | 판매중(마켓 열림) | `판매중` | 등록가 · 마감, `등록 취소` 만 |
/// | 판매중(아직 안 올라감) | `노출 대기` + 노출 시각 줄 | 위와 같다 |
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
    this.hours,
  });

  /// 내가 올린 매물. [MyTrade.isSale] 인 항목만 온다.
  final MyTrade trade;

  /// 지금 시각. 화면이 한 번 정해 모든 카드에 같은 값을 준다 — 카드마다
  /// `DateTime.now()` 를 부르면 목록 안에서 마감 기준이 미세하게 갈린다.
  final DateTime now;

  /// 마켓 운영 상태. 매물이 아직 남에게 안 보이는지([MarketHours.isListingVisible])
  /// 와 언제 보이는지([MarketHours.visibleFrom])를 이걸로 안다. 못 받았으면
  /// null 이라 그냥 `판매중` 으로 그린다 — 모르는 것을 단정하지 않는다.
  final MarketHours? hours;

  /// 가격 수정을 눌렀을 때. **null 이면 버튼 자체를 뺀다.** 마켓이 열려 있는
  /// 동안은 거래 중 가격이 고정이라 서버가 수정을 409 로 거절하므로(백엔드
  /// `MarketApi` 주석), 눌러서 거절당하게 두는 대신 그 시간에는 버튼을 안 낸다.
  final VoidCallback? onEditPrice;
  final VoidCallback onDelist;

  /// 아직 남에게 안 보이는 매물이면 그 매물이 올라가는 시각. 보이는 매물,
  /// 팔리는 중이 아닌 매물, 운영 상태를 모를 때는 null 이다.
  DateTime? get _exposureAt {
    final hours = this.hours;
    if (hours == null || trade.status != MyTradeStatus.listed) return null;
    // 판매 항목의 [MyTrade.occurredAt] 은 등록 시각이다.
    if (hours.isListingVisible(trade.occurredAt, now)) return null;
    return hours.visibleFrom(trade.occurredAt);
  }

  @override
  Widget build(BuildContext context) {
    final delisted = trade.status == MyTradeStatus.canceled;
    final exposureAt = _exposureAt;

    return TicketCard(
      child: Column(
        children: [
          TicketCardHeader(
            title: trade.concertTitle,
            posterImageUrl: trade.posterImageUrl,
            dimmed: delisted,
            badge: _badge(pending: exposureAt != null),
            infoLines: [
              (
                icon: Icons.calendar_today_outlined,
                text: trade.startAt == null
                    ? TicketStrings.dateUndecided
                    : formatPerformedAt(trade.startAt!),
              ),
              (icon: Icons.event_seat_outlined, text: trade.seatLabel),
              // 마켓 목록에 왜 없는지, 언제 생기는지. 안 올라간 매물에만 붙는다.
              if (exposureAt != null)
                (
                  icon: Icons.storefront_outlined,
                  text: TicketStrings.exposureAt(
                    formatMonthDayClock(exposureAt),
                  ),
                ),
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
  /// 팔리는 중이어도 아직 안 올라간 매물([pending])은 `판매중` 대신 `노출 대기` 다.
  Widget? _badge({required bool pending}) => switch (trade.status) {
    MyTradeStatus.listed => TicketBadge(
      label: pending
          ? TicketStrings.pendingExposureBadge
          : TicketStrings.listingBadge,
    ),
    MyTradeStatus.sold => const TicketBadge(label: TicketStrings.soldBadge),
    _ => null,
  };

  Widget _footer() => switch (trade.status) {
    MyTradeStatus.listed => Row(
      children: [
        if (onEditPrice case final onEditPrice?) ...[
          Expanded(
            child: TicketCardButton(
              label: TicketStrings.editPrice,
              onPressed: onEditPrice,
              filled: true,
            ),
          ),
          const SizedBox(width: 8),
        ],
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
