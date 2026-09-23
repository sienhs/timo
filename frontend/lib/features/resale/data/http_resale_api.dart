import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../ticket/models/ticket_status.dart';
import '../constants.dart';
import '../models/listable_ticket.dart';
import '../models/listing.dart';
import '../models/listing_detail.dart';
import '../models/market_concert.dart';
import '../models/market_hours.dart';
import '../models/my_trade.dart';
import '../models/purchased_trade.dart';
import '../utils/market_error.dart';
import 'resale_api.dart';

/// 백엔드 양도 마켓 API(`/api/v1/market`)에 실제로 요청하는 [ResaleApi].
/// 등록 가능한 티켓 목록만 마켓 밖(`GET /api/v1/tickets/me`)에서 골라 만든다.
/// 실패는 [ApiException] 으로 오고, 마켓만의 문구 손질은 [translateResaleError]
/// 가 한다. [dio] 와 [clock] 은 테스트를 위해 받는다.
class HttpResaleApi implements ResaleApi {
  HttpResaleApi({Dio? dio, this.clock = DateTime.now})
    : _dio = dio ?? ApiClient.dio;

  static const basePath = '/api/v1/market';

  /// 등록 가능한 티켓을 대신 읽는 곳. 내 티켓 화면이 쓰는 주소와 같다.
  static const myTicketsPath = '/api/v1/tickets/me';

  final Dio _dio;

  /// 기기 시각을 읽는 함수. 운영 상태 응답을 받은 시각([MarketHours.receivedAt])
  /// 을 찍는 데 쓴다.
  final DateTime Function() clock;

  /// 응답을 받은 기기 시각을 함께 넘긴다. 카운트다운의 기준점이라 요청 전이
  /// 아니라 응답이 온 뒤에 읽는다.
  @override
  Future<MarketHours> fetchMarketHours() async {
    final response = await _guard(() => _dio.get<dynamic>('$basePath/hours'));
    return MarketHours.fromJson(_body(response), receivedAt: clock());
  }

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
        options: Options(
          headers: {'Idempotency-Key': idempotencyKey},
          // 체인을 타는 요청이라 오래 기다린다([ResaleMetrics.onChainTimeout]).
          receiveTimeout: ResaleMetrics.onChainTimeout,
        ),
      ),
    );
    return PurchasedTrade.fromJson(_body(response));
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
      () => _dio.post<dynamic>(
        '$basePath/listings/$listingId/cancel',
        // 체인을 타는 요청이라 오래 기다린다([ResaleMetrics.onChainTimeout]).
        options: Options(receiveTimeout: ResaleMetrics.onChainTimeout),
      ),
    );
  }

  /// `PATCH` 다. 절댓값을 넣는 요청이라 두 번 도착해도 결과가 같고, 응답을
  /// 못 받고 끊겨도 다시 보내면 된다.
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

  /// 팔 수 있는 티켓만 남긴다 — 보유 상태이고 지금 마켓에 올라가 있지 않은
  /// 것. 나머지는 서버가 어차피 거절한다.
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
        // 체인을 타는 요청이라 오래 기다린다([ResaleMetrics.onChainTimeout]).
        options: Options(receiveTimeout: ResaleMetrics.onChainTimeout),
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

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거치므로
  /// 운영 시간 거절의 문구도 여기서 한 번에 바꾼다([translateResaleError]).
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw translateResaleError(ApiException.from(e));
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면(프록시가 HTML 을 준 경우 등) 화면용
  /// 예외로 바꾼다.
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
