import '../models/listable_ticket.dart';
import '../models/listing.dart';
import '../models/listing_detail.dart';
import '../models/market_concert.dart';
import '../models/market_hours.dart';
import '../models/my_trade.dart';
import '../models/purchased_trade.dart';
import '../models/trade_status.dart';

/// 양도마켓 화면들이 서버에 요청하는 일.
///
/// 화면은 이 인터페이스만 안다. [HttpResaleApi] 가 실제 서버에 요청하고,
/// 테스트와 화면 확인은 [MockResaleApi] 를 쓴다. 다른 도메인의 `XxxApi` 와
/// 같은 구조다.
///
/// 반환 규칙: 성공하면 결과를, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 빈 목록은 실패가 아니라 "올라온 매물이 없다" 는 정상 결과다.
///
/// **모든 요청이 로그인을 요구한다.** 마켓 API 는 `mine` 판정에 요청자가
/// 필요해서 조회까지 인증을 받는다(백엔드 `MarketApi` 주석). 화면은 비로그인
/// 상태에서 아예 부르지 않고 로그인 입구를 보여 준다.
///
/// 다른 도메인과 같이 실제 서버(v1)가 기본값이다. 시안 데이터로 보려면
/// `flutter run --dart-define=RESALE_API=mock`.
///
/// **내 거래 내역([fetchMyTrades]) · 등록 취소([cancelListing]) · 가격 수정
/// ([updateListingPrice])은 마켓 화면이 아니라 내 티켓 화면의 `양도 목록` 탭이
/// 쓴다.** 내 매물을 관리하는 자리가 그쪽이라(시안) 화면은 저기 있고, 요청은
/// 같은 마켓 API 로 나가므로 여기에 함께 둔다.
abstract class ResaleApi {
  /// 지금 마켓이 열려 있는지와 창의 시각. 판정은 서버 시계다.
  ///
  /// 화면은 이 값으로 목록을 감추고 버튼을 잠그거나 감추며 남은 시간을 그린다.
  /// 그러나 이것은 안내일 뿐이고 실제 차단은 각 요청이 409 로 한다(백엔드
  /// `MarketApi` 주석) — 이 값을 받은 뒤에 마켓이 열리거나 닫힐 수 있다.
  ///
  /// 시간 규칙은 요청마다 다르다.
  /// - 등록·취소·상세·내 거래 내역: 시간 무관. 올린 매물은 **등록 다음 날**
  ///   여는 시각부터 남에게 보인다.
  /// - 공연 목록·공연별 매물·구매: 열려 있을 때만, 그리고 올라온 매물만. 닫혀
  ///   있으면 409, 아직 안 올라온 매물을 사면 409.
  /// - 가격 수정: **닫혀 있을 때만**. 열려 있으면 409 — 거래 중 가격은 고정이다.
  Future<MarketHours> fetchMarketHours();

  /// 매물이 올라와 있는 공연 목록. 임박한 공연부터 온다.
  ///
  /// 매물이 하나도 없는 공연은 오지 않는다. 들어가 봐야 빈 화면이라 서버가
  /// 아예 뺀다. 마켓이 닫혀 있으면 409 다. 오늘 등록된 매물은 세지 않는다 —
  /// 매물은 등록 다음 날 여는 시각에 올라간다.
  Future<List<MarketConcert>> fetchConcerts();

  /// 공연 하나의 매물 목록. 낮은 가격순으로 온다. 마켓이 닫혀 있으면 409 고,
  /// 오늘 등록된 매물은 아직 없다.
  ///
  /// 내가 올린 매물도 함께 오고 `mine` 으로 구분된다 — 내 매물이 지금 어떤
  /// 가격대에 놓여 있는지 보여야 하기 때문이다.
  Future<List<Listing>> fetchListings(int concertId);

  /// 매물 한 건의 상세. 구매 확인 화면이 연다.
  ///
  /// 팔렸거나 내려간 매물도 정상 응답으로 온다. 살 수 있는지는
  /// [ListingDetail.status] 로 판단한다.
  Future<ListingDetail> fetchListing(int listingId);

  /// 매물을 산다. 선착순이며 응모·추첨·가격 제안은 없다. 운영 시간 밖이면
  /// 409 고, 아직 올라오지 않은 매물(오늘 등록)도 409 다 — 목록에는 없어도
  /// 번호로는 닿을 수 있어 서버가 여기서 막는다.
  ///
  /// [expectedPrice] 는 사용자가 화면에서 본 금액이다. 서버의 등록가와 다르면
  /// 거절된다 — 본 금액과 다른 금액이 빠져나가면 안 되기 때문이다.
  ///
  /// [idempotencyKey] 는 한 번의 구매 시도에 하나다. 재시도는 같은 키로 보내야
  /// 결제가 두 번 일어나지 않는다([newIdempotencyKey]).
  ///
  /// 성공해도 양도가 끝난 것은 아니다. 응답의 상태는 언제나 `PENDING` 이고,
  /// 소유권 이전은 [fetchTradeStatus] 로 확인한다.
  Future<PurchasedTrade> purchase({
    required int listingId,
    required int expectedPrice,
    required String idempotencyKey,
  });

  /// 체결 한 건의 지금 상태. 결제 완료 화면이 되풀이해 묻는다.
  ///
  /// 폴링 전용 주소가 따로 없어 내 거래 내역에서 같은 체결 번호를 찾아 읽는다
  /// (백엔드 `PurchaseResponseDto` 주석). 그 목록에 없으면(아직 반영 전)
  /// 진행 중으로 본다.
  Future<TradeStatus> fetchTradeStatus(int tradeId);

  /// 내 거래 내역. 내가 올린 매물(판매)과 내가 산 티켓(구매)이 같은 모양으로
  /// 한 목록에 섞여 온다. 정렬 기준은 [MyTrade.occurredAt] 이다.
  ///
  /// 팔렸거나 내린 매물도 함께 온다. 무엇을 그릴지는 화면이 [MyTrade.type] ·
  /// [MyTrade.status] 로 고른다 — 내 티켓의 양도 목록 탭은 판매만 그린다.
  Future<List<MyTrade>> fetchMyTrades();

  /// 내가 올린 매물을 내린다. 티켓은 다시 내 손으로 돌아와 취소·입장·재등록이
  /// 된다.
  ///
  /// 이미 팔렸거나 내린 매물이면 409, 내 매물이 아니면 403 을 `ApiException`
  /// 으로 받는다. 화면이 미리 걸러도 시점 차이로 통과할 수 있어 최종 판정은
  /// 서버 몫이다 — 예매 취소와 같은 규칙이다.
  Future<void> cancelListing(int listingId);

  /// 내가 올린 매물의 등록가를 바꾼다. 응답은 상세와 같은 모양이다.
  ///
  /// 매물 번호는 그대로다 — 내렸다 다시 올리면 새 매물이 되어 재양도 이력이
  /// 끊어져 보이기 때문에 서버가 수정 경로를 따로 둔다(백엔드 `MarketApi`
  /// 주석). [price] 는 등록 시점 정가 이하여야 한다. 화면(`ListingPrice`)이
  /// 먼저 거르고 서버도 같은 자리에서 거절한다.
  ///
  /// 남의 매물이면 403, 정가 초과면 400, 이미 팔렸거나 내린 매물이면 409 를
  /// `ApiException` 으로 받는다. 등록 취소와 같이 최종 판정은 서버 몫이다.
  ///
  /// **마켓이 열려 있는 동안은 409 다**(`MarketOpenException`). 구매자가 목록에서
  /// 본 값이 상세까지 바뀌지 않아야 해서, 가격은 닫힌 시간에만 바꿀 수 있다.
  Future<ListingDetail> updateListingPrice({
    required int listingId,
    required int price,
  });

  /// 내가 양도 등록할 수 있는 티켓 목록.
  ///
  /// 이 목록만 주는 서버 주소가 없어 내 티켓 목록에서 팔 수 있는 것(보유이고
  /// 등록 중 아님)만 골라 만든다([ListableTicket] 주석). 양도로 받은 티켓도
  /// 다시 팔 수 있어 함께 온다.
  Future<List<ListableTicket>> fetchListableTickets();

  /// 내 티켓을 매물로 등록한다.
  ///
  /// [price] 는 정가 이하여야 한다. 화면(`ListingPrice`)이 먼저 거르고, 서버도
  /// 같은 자리에서 거절한다. 등록되면 티켓은 취소·회수·입장이 막힌다.
  ///
  /// 운영 시간과 무관하게 받는다. 바로 `LISTED` 로 저장되지만 남에게는 **등록
  /// 다음 날** 여는 시각에 목록으로 드러난다. 내 거래 내역([fetchMyTrades])에는
  /// 바로 보인다.
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  });
}
