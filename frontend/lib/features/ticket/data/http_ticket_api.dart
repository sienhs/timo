import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import 'ticket_api.dart';

/// 백엔드 예매 API(`/api/v1/reservations`)에 실제로 요청하는 [TicketApi].
///
/// **로그인이 필요하다.** 목록은 서버가 요청한 회원의 주문만 골라 준다 — 그래서
/// "내" 티켓이다. 토큰은 `AuthInterceptor` 가 붙이고, 비로그인이면 401 이
/// 화면의 오류 안내로 그대로 나온다.
///
/// 로컬 백엔드는 시더가 시드 회원(`seed001` 등)에게 예매를 넣어 두므로, 그
/// 계정으로 로그인하면 목록이 바로 채워진다. 서버로는 만들 수 없는 상태(앱이
/// 모르는 주문 상태)를 볼 때만 [MockTicketApi] 를 쓴다
/// (`flutter run --dart-define=TICKET_API=mock-states`).
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpTicketApi implements TicketApi {
  HttpTicketApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const reservationsPath = '/api/v1/reservations';

  final Dio _dio;

  /// 상태로 거르지 않고 전부 받는다. 취소된 티켓도 회색 카드로 남겨 결과를
  /// 보여줘야 하기 때문이다. 거르는 일은 화면이 공연 날짜와 상태로 한다.
  @override
  Future<List<MyTicket>> fetchMyTickets() async {
    final content = await _content(reservationsPath, {
      'size': TicketMetrics.pageSize,
    });
    return content.map(MyTicket.fromJson).toList();
  }

  @override
  Future<void> cancelReservation(int reservationId) async {
    await _guard(
      () => _dio.delete<dynamic>('$reservationsPath/$reservationId'),
    );
  }

  /// 목록 응답은 Spring 의 `PagedModel` 이라 항목이 `content` 안에 있다.
  /// 한 번에 다 받으므로 `page` 정보는 읽지 않는다.
  Future<List<Map<String, dynamic>>> _content(
    String path,
    Map<String, Object> query,
  ) async {
    final response = await _guard(
      () => _dio.get<dynamic>(path, queryParameters: query),
    );
    final content = _body(response)['content'];
    if (content is! List) throw _unreadable(response);
    return content.whereType<Map<String, dynamic>>().toList();
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  ///
  /// `HttpAuthApi` · `HttpHomeApi` 와 같다. 세 곳이 같은 코드를 들고 있으니
  /// 다음에 하나가 더 생기면 `core/network` 로 올린다.
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
    TicketStrings.unreadableResponse,
    status: response.statusCode,
  );
}
