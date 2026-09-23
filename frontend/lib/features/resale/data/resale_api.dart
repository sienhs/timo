import '../models/listable_ticket.dart';
import '../models/listing.dart';
import '../models/listing_detail.dart';
import '../models/market_concert.dart';
import '../models/market_hours.dart';
import '../models/my_trade.dart';
import '../models/purchased_trade.dart';

/// 양도마켓 화면들이 서버에 요청하는 일. 실서버는 [HttpResaleApi], 테스트와
/// 화면 확인은 [MockResaleApi](`--dart-define=RESALE_API=mock`)다. 모든 요청이
/// 로그인을 요구하므로(`mine` 판정에 요청자가 필요) 비로그인이면 부르지 않는다.
///
/// 운영 시간 규칙은 요청마다 다르고, 실제 차단은 각 요청이 409 로 한다.
/// - 등록·취소·상세·내 거래 내역: 시간 무관.
/// - 공연 목록·공연별 매물·구매: 열려 있을 때만, 올라온 매물만.
/// - 가격 수정: 닫혀 있을 때만 — 거래 중 가격은 고정이다.
abstract class ResaleApi {
  /// 지금 마켓이 열려 있는지와 창의 시각. 판정은 서버 시계이며 이 값은
  /// 안내일 뿐이라, 받은 뒤에 마켓이 열리거나 닫힐 수 있다.
  Future<MarketHours> fetchMarketHours();

  /// 매물이 올라와 있는 공연 목록. 임박한 공연부터 오고 매물 없는 공연은
  /// 빠진다. 마켓이 닫혀 있으면 409.
  Future<List<MarketConcert>> fetchConcerts();

  /// 공연 하나의 매물 목록. 낮은 가격순이고 내 매물도 `mine` 으로 구분되어
  /// 함께 온다. 마켓이 닫혀 있으면 409.
  Future<List<Listing>> fetchListings(int concertId);

  /// 매물 한 건의 상세. 팔렸거나 내려간 매물도 정상 응답으로 오므로 살 수
  /// 있는지는 [ListingDetail.status] 로 판단한다.
  Future<ListingDetail> fetchListing(int listingId);

  /// 매물을 산다(선착순). 성공하면 코인 전송과 소유권 이전까지 끝나 있어
  /// 응답 상태는 언제나 `CONFIRMED` 고, 온체인 실패는 `TransferFailedException`.
  /// [expectedPrice] 가 서버 등록가와 다르면 거절 · 운영 시간 밖이거나 아직
  /// 안 올라온 매물이면 409. [idempotencyKey] 는 한 구매 시도에 하나다.
  Future<PurchasedTrade> purchase({
    required int listingId,
    required int expectedPrice,
    required String idempotencyKey,
  });

  /// 내 거래 내역. 판매(내가 올린 매물)와 구매(내가 산 티켓)가 같은 모양으로
  /// 한 목록에 섞여 오고, 팔렸거나 내린 매물도 온다. 무엇을 그릴지는 화면이
  /// [MyTrade.type] · [MyTrade.status] 로 고른다.
  Future<List<MyTrade>> fetchMyTrades();

  /// 내가 올린 매물을 내린다. 티켓은 다시 내 손으로 돌아온다. 이미 팔렸거나
  /// 내린 매물이면 409 · 내 매물이 아니면 403. 최종 판정은 서버 몫이다.
  Future<void> cancelListing(int listingId);

  /// 내가 올린 매물의 등록가를 바꾼다. 매물 번호는 그대로고 응답은 상세와
  /// 같은 모양이다. [price] 는 등록 시점 정가 이하여야 한다.
  /// 마켓이 열려 있으면 409(`MarketOpenException`) · 남의 매물이면 403 ·
  /// 정가 초과면 400 · 이미 팔렸거나 내린 매물이면 409.
  Future<ListingDetail> updateListingPrice({
    required int listingId,
    required int price,
  });

  /// 내가 양도 등록할 수 있는 티켓 목록. 전용 서버 주소가 없어 내 티켓
  /// 목록에서 팔 수 있는 것(보유이고 등록 중 아님)만 골라 만든다. 양도로
  /// 받은 티켓도 함께 온다.
  Future<List<ListableTicket>> fetchListableTickets();

  /// 내 티켓을 매물로 등록한다. 운영 시간과 무관하게 받는다. [price] 는 정가
  /// 이하여야 하며, 등록되면 티켓은 취소·회수·입장이 막힌다.
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  });
}
