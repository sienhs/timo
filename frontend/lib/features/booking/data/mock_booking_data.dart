import 'dart:math';

import '../models/performance.dart';
import '../models/seat.dart';
import '../models/zone.dart';

/// 목업용 고정 데이터. 구역별로 시드를 고정했으므로 실행할 때마다
/// 같은 좌석 배치가 나온다(시연 중 화면이 달라지면 설명이 어렵다).
///
/// 시안의 잔여좌석은 A 17석 / B 0석 / C 4석이지만, A를 17석으로 두면
/// 배치도가 거의 전부 회색이 되어 좌석 선택 자체를 시연할 수 없다.
/// 그래서 **A만** 넉넉히 남긴 상태로 바꿨고, 시안의 의도(B 매진 /
/// C 임박)는 그대로 유지했다. 화면에 찍히는 숫자는 아래 데이터에서
/// 계산하므로 배치도와 항상 일치한다.
class MockBookingData {
  MockBookingData._();

  /// 예매자 이름. 로그인이 붙으면 회원 정보에서 온다.
  static const bookerName = '홍길동';

  static final performance = Performance(
    title: '2026 아이유 콘서트',
    venue: '고척스카이돔',
    startAt: DateTime(2026, 11, 4, 18),
    posterAsset: 'assets/images/sample_poster.jpg',
    bookingFee: 3000,
  );

  static const zones = <Zone>[
    Zone(
      id: 'A',
      name: 'FLOOR A',
      price: 186000,
      rowCount: 15,
      seatsPerRow: 18,
    ),
    Zone(
      id: 'B',
      name: 'FLOOR B',
      price: 186000,
      rowCount: 12,
      seatsPerRow: 18,
    ),
    Zone(
      id: 'C',
      name: 'FLOOR C',
      price: 186000,
      rowCount: 8,
      seatsPerRow: 22,
    ),
  ];

  /// 구역 → 열 → 좌석. 열 단위 중첩 리스트로 두면 배치도를 그릴 때
  /// 인덱스 계산(row * seatsPerRow + n)이 필요 없어 실수가 줄어든다.
  static final Map<String, List<List<Seat>>> seatRowsByZone = {
    for (final zone in zones) zone.id: _generateRows(zone),
  };

  static List<List<Seat>> _generateRows(Zone zone) {
    final random = Random(zone.id.codeUnitAt(0));
    return [
      for (var row = 1; row <= zone.rowCount; row++)
        [
          for (var number = 1; number <= zone.seatsPerRow; number++)
            Seat(
              zoneId: zone.id,
              row: row,
              number: number,
              status: _statusFor(zone, row, random),
            ),
        ],
    ];
  }

  static SeatStatus _statusFor(Zone zone, int row, Random random) {
    final soldRate = switch (zone.id) {
      'B' => 1.0, // 매진 구역
      'C' => 0.97, // 잔여 임박 구역
      // 앞열이 더 많이 팔린 상태를 만들어 실제 공연장처럼 보이게 한다.
      _ => 0.30 + (1 - row / zone.rowCount) * 0.35,
    };

    return random.nextDouble() < soldRate
        ? SeatStatus.sold
        : SeatStatus.available;
  }
}
