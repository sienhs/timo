import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/data/resale_api.dart';
import 'package:timo/features/resale/models/listable_ticket.dart';
import 'package:timo/features/resale/models/listing.dart';
import 'package:timo/features/resale/models/listing_detail.dart';
import 'package:timo/features/resale/models/market_concert.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/models/purchased_trade.dart';
import 'package:timo/features/resale/models/trade_status.dart';

/// 내 티켓 화면이 마켓 API 에 무엇을 보냈는지 지켜보는 목. 실제 동작은
/// [MockResaleApi] 에 그대로 넘긴다.
///
/// "돌아오면 다시 받는다" · "그대로 두면 안 보낸다" 는 화면에 드러나지 않는
/// 약속이라 이렇게만 확인할 수 있다. 예매 쪽의 `_SpyApi` 와 같은 역할이다.
class SpyResaleApi implements ResaleApi {
  SpyResaleApi({DateTime Function() clock = DateTime.now, this.cancelFailure})
    : _base = MockResaleApi(latency: Duration.zero, clock: clock);

  final MockResaleApi _base;

  /// 등록 취소가 던질 실패. 없으면 목에 그대로 넘긴다.
  final ApiException? cancelFailure;

  /// 등록 취소가 나간 매물 번호. 나간 순서대로다.
  final cancelled = <int>[];

  /// 내 거래 내역을 몇 번 받아 갔나.
  int myTradesCalls = 0;

  @override
  Future<void> cancelListing(int listingId) async {
    if (cancelFailure case final failure?) throw failure;
    cancelled.add(listingId);
    await _base.cancelListing(listingId);
  }

  @override
  Future<List<MyTrade>> fetchMyTrades() {
    myTradesCalls++;
    return _base.fetchMyTrades();
  }

  @override
  Future<List<MarketConcert>> fetchConcerts() => _base.fetchConcerts();

  @override
  Future<List<Listing>> fetchListings(int concertId) =>
      _base.fetchListings(concertId);

  @override
  Future<ListingDetail> fetchListing(int listingId) =>
      _base.fetchListing(listingId);

  @override
  Future<PurchasedTrade> purchase({
    required int listingId,
    required int expectedPrice,
    required String idempotencyKey,
  }) => _base.purchase(
    listingId: listingId,
    expectedPrice: expectedPrice,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TradeStatus> fetchTradeStatus(int tradeId) =>
      _base.fetchTradeStatus(tradeId);

  @override
  Future<List<ListableTicket>> fetchListableTickets() =>
      _base.fetchListableTickets();

  @override
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  }) => _base.createListing(ticketId: ticketId, price: price);
}
