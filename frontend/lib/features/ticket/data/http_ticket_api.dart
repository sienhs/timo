import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/entry_pass.dart';
import '../models/my_ticket.dart';
import '../models/reservation_detail.dart';
import 'ticket_api.dart';

/// 백엔드 티켓 API(`/api/v1/tickets`)와 예매 API(`/api/v1/reservations`)에
/// 실제로 요청하는 [TicketApi]. 로그인이 필요하다 — 토큰은 `AuthInterceptor` 가
/// 붙이고, 비로그인이면 401 이 화면의 오류 안내로 그대로 나온다.
class HttpTicketApi implements TicketApi {
  HttpTicketApi({Dio? dio, DateTime Function()? clock})
    : _dio = dio ?? ApiClient.dio,
      _clock = clock ?? DateTime.now;

  static const reservationsPath = '/api/v1/reservations';
  static const ticketsPath = '/api/v1/tickets';

  final Dio _dio;

  /// 입장 QR 응답을 받은 시각을 찍는 데 쓴다. 서버는 만료 시각이 아니라 남은
  /// 초만 주므로, 세기 시작할 기준점은 응답을 손에 넣은 여기서 찍어야 한다.
  final DateTime Function() _clock;

  /// 소유 기준 목록(`/tickets/me`)이다. 예매 목록(`/reservations`)은 양도로 판
  /// 티켓이 남고 산 티켓이 없다. 상태로 거르지 않고 전부 받는다 — 회수된 티켓도
  /// 회색 카드로 남겨야 해서, 거르는 일은 화면이 한다.
  @override
  Future<List<MyTicket>> fetchMyTickets() async {
    final content = await _content('$ticketsPath/me', {
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

  /// 본문은 백엔드 `CreateReservationRequestDto` 와 필드 이름이 같다. 결제
  /// 수단은 보내지 않는다 — 결제는 예치 잔액 차감 한 가지뿐이다.
  @override
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  }) async {
    final response = await _guard(
      () => _dio.post<dynamic>(
        reservationsPath,
        data: {'concertId': concertId, 'seatId': seatId},
      ),
    );
    return ReservationDetail.fromJson(_body(response));
  }

  @override
  Future<ReservationDetail> fetchReservation(int reservationId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$reservationsPath/$reservationId'),
    );
    return ReservationDetail.fromJson(_body(response));
  }

  /// GET 이다. 발급이 서버 상태를 바꾸지 않아 만료마다 다시 불러도 된다(백엔드
  /// `EntryPassApi`). 409 의 사유(시간대·티켓 상태)는 서버 문구를 그대로 올린다.
  @override
  Future<EntryPass> issueEntryPass(int ticketId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$ticketsPath/$ticketId/entry-pass'),
    );
    return EntryPass.fromJson(_body(response), receivedAt: _clock());
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
  /// `HttpAuthApi` · `HttpHomeApi` 와 같은 코드라, 하나 더 생기면 `core/network` 로 올린다.
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
