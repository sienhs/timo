import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/network/server_errors.dart';
import '../constants.dart';
import '../models/captcha_challenge.dart';
import '../models/seat.dart';
import '../models/seat_hold.dart';
import '../models/zone.dart';
import '../models/zone_seats.dart';
import 'booking_api.dart';
import 'mock_booking_data.dart';

/// 서버 없이 도는 [BookingApi]. 테스트가 쓴다. 고정 배치도([MockBookingData])
/// 위에 이 인스턴스에서 한 선점만 덧씌운다. 실제 규칙대로 한 공연에서 한 자리만
/// 유지되고, 새 자리를 잡으면 이전 자리가 풀리며 그 번호를 알려 준다.
class MockBookingApi implements BookingApi {
  MockBookingApi({this.latency = BookingConstants.mockLatency});

  /// 실제 서버처럼 로딩 상태가 보이게 하는 지연.
  final Duration latency;

  /// 공연 → 지금 잡고 있는 좌석 번호.
  final Map<int, int> _heldSeats = {};

  /// 좌석 번호 → 덮어쓴 상태. 여기 없는 좌석은 고정 배치도 그대로다.
  final Map<int, SeatStatus> _overrides = {};

  /// 보안문자 정답. 로컬 백엔드의 가짜 캡차(`StubCaptchaClient`)와 같은 값이다.
  /// 대소문자는 가리지 않는다.
  static const captchaAnswer = 'timo';

  /// 1×1 투명 PNG. 테스트에서 `Image.memory` 가 디코딩할 수 있는 가장 작은 그림이다.
  static const _captchaImageBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  int _issuedCaptchaCount = 0;

  /// 아직 확인에 쓰이지 않은 보안문자 키.
  final Set<String> _liveCaptchaKeys = {};

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

  @override
  Future<CaptchaChallenge> issueCaptcha() async {
    await _delay();
    final key = 'mock-captcha-${++_issuedCaptchaCount}';
    _liveCaptchaKeys.add(key);
    return CaptchaChallenge(
      captchaKey: key,
      image: base64Decode(_captchaImageBase64),
      expiresIn: const Duration(minutes: 2),
    );
  }

  /// 좌석 조회를 막지는 않는다. 막으면 좌석 화면만 보는 테스트가 전부 보안문자를
  /// 거쳐야 한다. 통과를 요구하는 경우는 테스트가 가짜 API 로 403 을 흉내 낸다.
  @override
  Future<void> verifyCaptcha({
    required int concertId,
    required String captchaKey,
    required String value,
  }) async {
    await _delay();
    // 서버처럼 한 번 쓴 키는 맞든 틀리든 사라진다. 문구도 서버 것 그대로다.
    if (!_liveCaptchaKeys.remove(captchaKey)) {
      throw const ApiException(
        '만료되었거나 존재하지 않는 캡차입니다.',
        status: 404,
        exceptionName: BookingServerErrors.captchaKeyNotFound,
      );
    }
    if (value.toLowerCase() != captchaAnswer) {
      throw const ApiException(
        '캡차 입력값이 올바르지 않습니다.',
        status: 400,
        exceptionName: BookingServerErrors.captchaMismatch,
      );
    }
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
