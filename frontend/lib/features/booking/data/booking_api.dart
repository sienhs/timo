import '../models/seat_hold.dart';
import '../models/zone.dart';
import '../models/zone_seats.dart';

/// 예매 흐름(구역 고르기 → 좌석 고르기)이 서버에 요청하는 일 네 가지. 화면은 이
/// 인터페이스만 알고, 실패는 `ApiException` 으로 던진다(401 로그인 필요 · 409 남이
/// 먼저 잡음). 좌석은 공연마다 상태가 다르므로 모든 요청이 공연 번호를 받는다.
abstract class BookingApi {
  /// 이 공연의 구역을 잔여석과 함께 받는다. 개별 좌석은 담기지 않는다.
  Future<List<Zone>> fetchZones(int concertId);

  /// 구역 하나의 좌석 배치도를 받는다.
  ///
  /// 페이지로 나뉘지 않는다. 배치도는 좌석이 전부 있어야 그려진다.
  Future<ZoneSeats> fetchSeats({required int concertId, required int zoneId});

  /// 좌석을 5분간 잡아 둔다. 한 계정은 한 공연에서 한 자리만 잡을 수 있어 새로
  /// 잡으면 이전 자리가 풀리고 `releasedSeatId` 로 온다. 로그인이 없으면 401.
  Future<SeatHold> holdSeat({required int concertId, required int seatId});

  /// 잡아 둔 좌석을 푼다. 이미 빈 자리를 풀어도 성공이다(멱등). 남이 잡은 자리만
  /// 403 으로 거절된다.
  Future<void> cancelHold({required int concertId, required int seatId});
}
