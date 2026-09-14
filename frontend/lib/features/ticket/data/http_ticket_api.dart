import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import 'ticket_api.dart';

/// 백엔드 예매·양도 API 에 실제로 요청하는 [TicketApi].
///
/// 지금은 프론트 연동용 스텁(`/api/v0`)에 붙어 있다. 스텁은 실제 컨트롤러와
/// 같은 `ReservationApi` 인터페이스를 구현하므로 요청·응답 모양이 v1 과 같다.
/// 티켓 도메인 실제 API 가 열리면 [reservationsPath] 의 버전만 `v1` 으로 바꾼다.
///
/// **v0 스텁으로는 화면을 채울 수 없다.** 주문하려면 공연이 `ON_SALE` 이어야
/// 하는데 고정 공연 4개 중 하나뿐이고, 1인 1매라 만들 수 있는 티켓이 한 장이다.
/// 지난 공연은 아예 만들 수 없다. 화면을 눈으로 볼 때는 [MockTicketApi] 를 쓴다
/// (`flutter run --dart-define=TICKET_API=mock`).
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpTicketApi implements TicketApi {
  HttpTicketApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const reservationsPath = '/api/v0/reservations';

  final Dio _dio;

  /// 상태로 거르지 않고 전부 받는다. 발행 중·실패·취소된 티켓도 카드로 그려야
  /// 하기 때문이다. 거르는 일은 화면이 공연 날짜와 상태로 한다.
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
