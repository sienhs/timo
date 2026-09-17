import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../ticket/models/ticket_status.dart';
import '../constants.dart';
import '../models/listable_ticket.dart';
import '../models/listing.dart';
import '../models/listing_detail.dart';
import '../models/market_concert.dart';
import '../models/my_trade.dart';
import '../models/purchased_trade.dart';
import '../models/trade_status.dart';
import 'resale_api.dart';

/// 백엔드 양도 마켓 API(`/api/v1/market`)에 실제로 요청하는 [ResaleApi].
///
/// v0 스텁과 v1 실제 컨트롤러가 같은 규약(`MarketApi`)을 구현하므로 응답
/// 모양은 같고 [basePath] 만 다르다. 스텁으로 보려면 이 값만 v0 으로 바꾼다.
///
/// **등록 가능한 티켓 목록만 마켓 밖에서 온다.** 그 경로가 없어 내 티켓 목록
/// (`GET /api/v1/tickets/me`)에서 팔 수 있는 것만 골라 만든다([ListableTicket]
/// 주석). 예전엔 예매 목록으로 만들었는데, 그쪽엔 등록 여부가 없어 이미 올린
/// 티켓이 후보에 남고 양도로 받은 티켓은 빠졌다(S15P21D206-331 에서 바꿈).
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpResaleApi implements ResaleApi {
  HttpResaleApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const basePath = '/api/v1/market';

  /// 등록 가능한 티켓을 대신 읽는 곳. 내 티켓 화면이 쓰는 주소와 같다.
  static const myTicketsPath = '/api/v1/tickets/me';

  final Dio _dio;

  @override
  Future<List<MarketConcert>> fetchConcerts() async {
    final content = await _content('$basePath/concerts');
    return content.map(MarketConcert.fromJson).toList();
  }

  @override
  Future<List<Listing>> fetchListings(int concertId) async {
    final content = await _content('$basePath/concerts/$concertId/listings');
    return content.map(Listing.fromJson).toList();
  }

  @override
  Future<ListingDetail> fetchListing(int listingId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$basePath/listings/$listingId'),
    );
    return ListingDetail.fromJson(_body(response));
  }

  @override
  Future<PurchasedTrade> purchase({
    required int listingId,
    required int expectedPrice,
    required String idempotencyKey,
  }) async {
    final response = await _guard(
      () => _dio.post<dynamic>(
        '$basePath/listings/$listingId/purchase',
        data: {'expectedPrice': expectedPrice},
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      ),
    );
    return PurchasedTrade.fromJson(_body(response));
  }

  /// 내 거래 내역에서 같은 체결 번호를 찾아 상태만 꺼낸다.
  ///
  /// 폴링 전용 주소가 따로 없어 [fetchMyTrades] 위에서 골라낸다. 두 상태 값은
  /// 서버가 같은 이름을 쓰므로 이름으로 옮긴다.
  ///
  /// 목록에 아직 없으면(반영 전) 진행 중으로 본다. 없다는 것은 실패했다는
  /// 뜻이 아니라 아직 모른다는 뜻이다.
  @override
  Future<TradeStatus> fetchTradeStatus(int tradeId) async {
    final trades = await fetchMyTrades();
    for (final trade in trades) {
      if (trade.tradeId == tradeId) {
        return TradeStatus.fromWire(trade.status.wireName);
      }
    }
    return TradeStatus.pending;
  }

  @override
  Future<List<MyTrade>> fetchMyTrades() async {
    final content = await _content('$basePath/listings/me');
    return content.map(MyTrade.fromJson).toList();
  }

  /// 성공은 204 로 본문이 없다. 읽을 것이 없으니 실패만 [ApiException] 으로
  /// 바꾼다.
  @override
  Future<void> cancelListing(int listingId) async {
    await _guard(
      () => _dio.post<dynamic>('$basePath/listings/$listingId/cancel'),
    );
  }

  /// `PATCH` 다. 절댓값을 넣는 요청이라 같은 요청이 두 번 도착해도 결과가
  /// 같고, 그래서 응답을 못 받고 끊겨도 다시 보내면 된다(백엔드 `MarketApi`
  /// 주석). 이 API 에서 PATCH 를 쓰는 곳은 여기 하나다.
  @override
  Future<ListingDetail> updateListingPrice({
    required int listingId,
    required int price,
  }) async {
    final response = await _guard(
      () => _dio.patch<dynamic>(
        '$basePath/listings/$listingId/price',
        data: {'price': price},
      ),
    );
    return ListingDetail.fromJson(_body(response));
  }

  /// 팔 수 있는 티켓만 남긴다 — 발행이 끝나 손에 있고(보유), 지금 마켓에
  /// 올라가 있지 않은 것. 내 티켓 화면의 "쓸 수 있는가" 와 같은 조건이다.
  /// 등록 중인 티켓을 남기면 골라서 등록을 눌러야 서버 거절을 받고, 발행 중·
  /// 입장 완료·회수된 티켓은 서버가 어차피 거절한다.
  @override
  Future<List<ListableTicket>> fetchListableTickets() async {
    final content = await _content(myTicketsPath);
    return content
        .where(
          (json) =>
              json['ticketStatus'] == TicketStatus.owned.wireName &&
              json['listed'] != true,
        )
        .map(ListableTicket.fromMyTicketJson)
        .toList();
  }

  @override
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  }) async {
    final response = await _guard(
      () => _dio.post<dynamic>(
        '$basePath/listings',
        data: {'ticketId': ticketId, 'price': price},
      ),
    );
    return ListingDetail.fromJson(_body(response));
  }

  /// 목록 응답은 Spring 의 `PagedModel` 이라 항목이 `content` 안에 있다.
  /// 한 번에 다 받으므로([ResaleMetrics.pageSize]) `page` 정보는 읽지 않는다.
  Future<List<Map<String, dynamic>>> _content(String path) async {
    final response = await _guard(
      () => _dio.get<dynamic>(
        path,
        queryParameters: {'size': ResaleMetrics.pageSize},
      ),
    );
    final content = _body(response)['content'];
    if (content is! List) throw _unreadable(response);
    return content.whereType<Map<String, dynamic>>().toList();
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  ///
  /// `HttpAuthApi` · `HttpHomeApi` · `HttpTicketApi` 와 같은 코드다. 네 곳이
  /// 같은 것을 들고 있으니 `core/network` 로 올릴 때가 됐다 — 이 작업(화면
  /// 구현)에서 네 도메인의 API 구현을 함께 건드리지 않으려고 미뤄 둔다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면(프록시가 HTML 을 준 경우 등) 화면용
  /// 예외로 바꿔서, 화면이 형 변환 오류 대신 안내 문구를 받게 한다.
  Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw _unreadable(response);
  }

  ApiException _unreadable(Response<dynamic> response) => ApiException(
    ResaleStrings.unreadableResponse,
    status: response.statusCode,
  );
}
