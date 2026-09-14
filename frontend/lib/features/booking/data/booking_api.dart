import '../models/seat_hold.dart';
import '../models/zone.dart';
import '../models/zone_seats.dart';

/// 예매 흐름(구역 고르기 → 좌석 고르기)이 서버에 요청하는 일 네 가지.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpBookingApi] 가 실제 서버에
/// 요청하고, 테스트와 서버 없이 화면을 볼 때는 [MockBookingApi] 를 쓴다.
/// 홈의 `HomeApi`, 내 티켓의 `TicketApi` 와 같은 구조다.
///
/// **모든 요청이 공연 번호를 받는다.** 좌석은 공연장에 딸린 자리라 여러 공연이
/// 같은 자리를 나눠 쓰고, 팔렸는지 잡혔는지는 공연마다 다르다. 공연을 빼고
/// 물으면 어느 날 공연의 좌석표인지 정해지지 않는다.
///
/// 반환 규칙: 성공하면 결과를, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 화면이 사유별로 갈라야 하는 실패는 예외의 상태 코드로 가른다 —
/// 401 은 로그인이 필요하다는 뜻이고, 409 는 그 사이 남이 자리를 가져갔다는
/// 뜻이다.
abstract class BookingApi {
  /// 이 공연의 구역을 잔여석과 함께 받는다. 개별 좌석은 담기지 않는다.
  Future<List<Zone>> fetchZones(int concertId);

  /// 구역 하나의 좌석 배치도를 받는다.
  ///
  /// 페이지로 나뉘지 않는다. 배치도는 좌석이 전부 있어야 그려진다.
  Future<ZoneSeats> fetchSeats({required int concertId, required int zoneId});

  /// 좌석을 5분간 잡아 둔다.
  ///
  /// 한 계정은 한 공연에서 한 자리만 잡을 수 있어, 새로 잡으면 이전 자리가
  /// 자동으로 풀린다. 풀린 자리는 결과의 `releasedSeatId` 로 온다.
  ///
  /// **로그인이 필요하다.** 서버가 요청자를 특정하지 못하면 401 이다.
  Future<SeatHold> holdSeat({required int concertId, required int seatId});

  /// 잡아 둔 좌석을 푼다. 자리는 즉시 예매 가능으로 돌아간다.
  ///
  /// 이미 빈 자리를 풀어도 성공이다(멱등). 만료 직후에 취소를 눌러도 화면에
  /// 오류가 뜨지 않는다. 남이 잡은 자리만 403 으로 거절된다.
  Future<void> cancelHold({required int concertId, required int seatId});
}
