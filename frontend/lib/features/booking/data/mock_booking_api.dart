import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/seat.dart';
import '../models/seat_hold.dart';
import '../models/zone.dart';
import '../models/zone_seats.dart';
import 'booking_api.dart';
import 'mock_booking_data.dart';

/// 서버 없이 도는 [BookingApi]. **테스트가 쓴다.**
///
/// 고정 배치도([MockBookingData]) 위에 이 인스턴스에서 한 선점만 덧씌운다.
/// 그래서 잡은 자리를 다시 조회하면 선점중으로 보이고, 취소하면 되돌아온다.
///
/// 실제 규칙대로 선점은 한 공연에서 한 자리만 유지된다. 새 자리를 잡으면 이전
/// 자리가 풀리고 그 번호를 알려 준다.
///
/// 앱에서 이걸로 갈아끼우는 실행 인자가 있었는데 지웠다. 서버 로컬 시드가
/// 좌석 상태를 채우지 않던 시절, 회색 자리를 눈으로 보려면 이 목뿐이었기
/// 때문이다. 이제 시드가 판매 완료·선점을 만들어 실제 서버로 보인다. 앱은
/// 언제나 서버를 본다.
class MockBookingApi implements BookingApi {
  MockBookingApi({this.latency = BookingConstants.mockLatency});

  /// 실제 서버처럼 로딩 상태가 보이게 하는 지연.
  final Duration latency;

  /// 공연 → 지금 잡고 있는 좌석 번호.
  final Map<int, int> _heldSeats = {};

  /// 좌석 번호 → 덮어쓴 상태. 여기 없는 좌석은 고정 배치도 그대로다.
  final Map<int, SeatStatus> _overrides = {};

  @override
  Future<List<Zone>> fetchZones(int concertId) async {
    await _delay();
    return [
      for (final zone in MockBookingData.zones)
        Zone(
          id: zone.id,
          name: zone.name,
          price: zone.price,
          seatCount: zone.seatCount,
          // 잡아 둔 자리는 잔여석에서 빠져야 배치도와 숫자가 어긋나지 않는다.
          availableCount: _availableCountOf(zone.id),
          rowCount: zone.rowCount,
          seatsPerRow: zone.seatsPerRow,
        ),
    ];
  }

  @override
  Future<ZoneSeats> fetchSeats({
    required int concertId,
    required int zoneId,
  }) async {
    await _delay();
    final zone = _zoneOf(zoneId);
    final rows = _rowsOf(zoneId);

    return ZoneSeats(
      zoneId: zone.id,
      zoneName: zone.name,
      price: zone.price,
      seatCount: zone.seatCount,
      availableCount: _availableCountOf(zoneId),
      rows: rows,
    );
  }

  @override
  Future<SeatHold> holdSeat({
    required int concertId,
    required int seatId,
  }) async {
    await _delay();

    final seat = _seatOf(seatId);
    if (seat == null) throw const ApiException('존재하지 않는 좌석입니다.', status: 404);

    final current = _statusOf(seat);
    // 이미 내가 잡고 있는 자리를 다시 누르면 만료만 미뤄 준다(서버와 같다).
    final mine = _heldSeats[concertId] == seatId;
    if (!mine && current != SeatStatus.available) {
      throw const ApiException('이미 선택된 좌석입니다.', status: 409);
    }

    final previous = _heldSeats[concertId];
    if (previous != null && previous != seatId) _overrides.remove(previous);

    _heldSeats[concertId] = seatId;
    _overrides[seatId] = SeatStatus.held;

    final now = DateTime.now();
    return SeatHold(
      seatId: seatId,
      // 실제 서버는 잡은 자리가 속한 구역의 값을 준다. 목 데이터는 구역이
      // 달라도 금액이 같아(요구사항상 좌석 등급이 없다) 상수를 바로 쓴다.
      price: MockBookingData.price,
      expiresAt: now.add(BookingConstants.holdDuration),
      heldAt: now,
      releasedSeatId: previous == seatId ? null : previous,
    );
  }

  @override
  Future<void> cancelHold({required int concertId, required int seatId}) async {
    await _delay();
    // 이미 빈 자리를 풀어도 성공이다. 취소는 멱등하다.
    if (_heldSeats[concertId] != seatId) return;
    _heldSeats.remove(concertId);
    _overrides.remove(seatId);
  }

  Future<void> _delay() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Zone _zoneOf(int zoneId) =>
      MockBookingData.zones.firstWhere((zone) => zone.id == zoneId);

  List<List<Seat?>> _rowsOf(int zoneId) => [
    for (final row in MockBookingData.seatRowsByZone[zoneId]!)
      [
        for (final seat in row)
          seat == null
              ? null
              : Seat(
                  id: seat.id,
                  row: seat.row,
                  number: seat.number,
                  status: _statusOf(seat),
                ),
      ],
  ];

  SeatStatus _statusOf(Seat seat) => _overrides[seat.id] ?? seat.status;

  Seat? _seatOf(int seatId) {
    for (final rows in MockBookingData.seatRowsByZone.values) {
      for (final row in rows) {
        for (final seat in row) {
          if (seat?.id == seatId) return seat;
        }
      }
    }
    return null;
  }

  int _availableCountOf(int zoneId) => _rowsOf(zoneId).fold(
    0,
    (sum, row) => sum + row.where((seat) => seat?.isSelectable ?? false).length,
  );
}
