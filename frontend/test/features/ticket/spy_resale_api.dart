import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/data/resale_api.dart';
import 'package:timo/features/resale/models/listable_ticket.dart';
import 'package:timo/features/resale/models/listing.dart';
import 'package:timo/features/resale/models/listing_detail.dart';
import 'package:timo/features/resale/models/market_concert.dart';
import 'package:timo/features/resale/models/market_hours.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/models/purchased_trade.dart';

/// 내 티켓 화면이 마켓 API 에 무엇을 보냈는지 지켜보는 목. 실제 동작은
/// [MockResaleApi] 에 그대로 넘긴다. "돌아오면 다시 받는다" · "그대로 두면
/// 안 보낸다" 는 화면에 드러나지 않는 약속이라 이걸로만 확인할 수 있다.
class SpyResaleApi implements ResaleApi {
  SpyResaleApi({
    DateTime Function() clock = DateTime.now,
    this.cancelFailure,
    this.priceFailure,
    this.extraTrades = const [],
  }) : _base = MockResaleApi(latency: Duration.zero, clock: clock);

  final MockResaleApi _base;

  /// 목에 없는 내 거래를 목록 앞에 얹는다. 더보기의 `양도 등록 취소` 는 티켓과
  /// 매물을 좌석으로 맞춰 찾는데, 예매 목과 마켓 목은 서로 다른 공연이라 겹치는
  /// 좌석이 없다. 맞는 매물이 있는 경우를 보려면 여기로 넣어 준다.
  final List<MyTrade> extraTrades;

  /// 등록 취소가 던질 실패. 없으면 목에 그대로 넘긴다.
  final ApiException? cancelFailure;

  /// 가격 수정이 던질 실패. 없으면 목에 그대로 넘긴다.
  final ApiException? priceFailure;

  /// 등록 취소가 나간 매물 번호. 나간 순서대로다.
  final cancelled = <int>[];

  /// 가격 수정이 나간 (매물 번호, 새 가격). 나간 순서대로다.
  final priceUpdates = <({int listingId, int price})>[];

  /// 내 거래 내역을 몇 번 받아 갔나.
  int myTradesCalls = 0;

  @override
  Future<void> cancelListing(int listingId) async {
    if (cancelFailure case final failure?) throw failure;
    cancelled.add(listingId);
    await _base.cancelListing(listingId);
  }

  @override
  Future<ListingDetail> updateListingPrice({
    required int listingId,
    required int price,
  }) {
    if (priceFailure case final failure?) throw failure;
    priceUpdates.add((listingId: listingId, price: price));
    return _base.updateListingPrice(listingId: listingId, price: price);
  }

  @override
  Future<MarketHours> fetchMarketHours() => _base.fetchMarketHours();

  @override
  Future<List<MyTrade>> fetchMyTrades() async {
    myTradesCalls++;
    return [...extraTrades, ...await _base.fetchMyTrades()];
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
  Future<List<ListableTicket>> fetchListableTickets() =>
      _base.fetchListableTickets();

  @override
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  }) => _base.createListing(ticketId: ticketId, price: price);
}
