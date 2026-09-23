import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/seat_hold.dart';
import '../models/zone.dart';
import '../models/zone_seats.dart';
import 'booking_api.dart';

/// 백엔드 구역·좌석 API 에 실제로 요청하는 [BookingApi]. 서버 주소·시간 제한은
/// [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은 [ApiException] 이 맡는다.
/// 선점은 요청자가 DB 에 실제로 있어야 성공한다 — 회원이 없으면 자리가 비어
/// 있어도 409 다. [dio] 는 테스트를 위해 받는다.
class HttpBookingApi implements BookingApi {
  HttpBookingApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const sectionsPath = '/api/v1/sections';
  static const seatsPath = '/api/v1/seats';

  final Dio _dio;

  @override
  Future<List<Zone>> fetchZones(int concertId) async {
    final response = await _guard(
      () => _dio.get<dynamic>(
        sectionsPath,
        queryParameters: {'concertId': concertId},
      ),
    );

    final sections = _body(response)['sections'];
    if (sections is! List) throw _unreadable(response);
    return sections
        .whereType<Map<String, dynamic>>()
        .map(Zone.fromJson)
        .toList();
  }

  @override
  Future<ZoneSeats> fetchSeats({
    required int concertId,
    required int zoneId,
  }) async {
    final response = await _guard(
      () => _dio.get<dynamic>(
        seatsPath,
        queryParameters: {'concertId': concertId, 'sectionId': zoneId},
      ),
    );
    return ZoneSeats.fromJson(_body(response));
  }

  @override
  Future<SeatHold> holdSeat({
    required int concertId,
    required int seatId,
  }) async {
    final response = await _guard(
      () => _dio.post<dynamic>(
        _holdPath(seatId),
        queryParameters: {'concertId': concertId},
      ),
    );
    return SeatHold.fromJson(_body(response));
  }

  @override
  Future<void> cancelHold({required int concertId, required int seatId}) async {
    await _guard(
      () => _dio.delete<dynamic>(
        _holdPath(seatId),
        queryParameters: {'concertId': concertId},
      ),
    );
  }

  String _holdPath(int seatId) => '$seatsPath/$seatId/hold';

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  /// `HttpAuthApi` · `HttpHomeApi` · `HttpTicketApi` 에도 같은 코드가 있다.
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
    BookingStrings.unreadableResponse,
    status: response.statusCode,
  );
}
