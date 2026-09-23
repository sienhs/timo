import 'dart:math';

import '../models/performance.dart';
import '../models/seat.dart';
import '../models/zone.dart';

/// 서버 없이 예매 화면을 볼 때 쓰는 고정 데이터.
///
/// 구역별로 시드를 고정했으므로 실행할 때마다 같은 좌석 배치가 나온다(시연 중
/// 화면이 달라지면 설명이 어렵다).
///
/// 구역 수·좌석 수는 서버(구역 5개 × 200석)와 같게 맞췄다. 목으로 보던 화면과
/// 서버로 본 화면의 규모가 달라지지 않게 하려는 것이다.
///
/// 시안의 잔여좌석은 A 17석 / B 0석 / C 4석이지만, A를 17석으로 두면 배치도가
/// 거의 전부 회색이 되어 좌석 선택 자체를 시연할 수 없다. 그래서 **A만**
/// 넉넉히 남긴 상태로 바꿨고, 시안의 의도(B 매진 / C 임박)는 유지했다. 화면에
/// 찍히는 숫자는 아래 데이터에서 계산하므로 배치도와 항상 일치한다.
///
/// **선점중 좌석을 여기서 섞는 이유**가 있다. 서버 로컬 시드는 좌석 상태를
/// 넣지 않아 전 좌석이 예매 가능으로 온다. 남이 잡고 있는 자리가 어떻게
/// 보이는지는 이 목으로만 확인할 수 있다.
class MockBookingData {
  MockBookingData._();

  /// 예매를 시작하기 전에 세워 두는 공연. 상세 화면에서 들어오면 진짜 공연으로
  /// 바뀐다(`BookingController.startBooking`). 흐름 밖에서 열린 화면이 빈
  /// 머리말을 그리지 않게 하는 자리다.
  static final performance = Performance(
    title: '2026 아이유 콘서트',
    venue: '고척스카이돔',
    startAt: DateTime(2026, 11, 4, 18),
  );

  /// 구역 하나의 격자. 서버 시드와 같은 10열 × 20번 = 200석이다.
  static const rowCount = 10;
  static const seatsPerRow = 20;

  /// 요구사항상 좌석 등급이 없어 모든 자리가 같은 금액이다.
  static const price = 186000;

  /// 구역 이름과 팔린 비율.
  ///
  /// 배치도가 이 순서대로 자리를 잡는다(앞 셋은 1층, 뒤 둘은 2층 스탠드).
  /// 순서를 바꾸면 그림이 바뀐다.
  static const _seeds = <({String name, double soldRate})>[
    (name: 'FLOOR A', soldRate: 0.30), // 앞열이 더 팔린 구역. 아래에서 열마다 더한다
    (name: 'FLOOR B', soldRate: 1.00), // 매진 구역
    (name: 'FLOOR C', soldRate: 0.97), // 잔여 임박 구역
    // 2층은 1층보다 덜 팔린 상태로 둔다. 다섯 구역이 비슷하게 차 있으면
    // 잔여좌석 패널에서 구역을 고를 이유가 보이지 않는다.
    (name: 'FLOOR D', soldRate: 0.55),
    (name: 'FLOOR E', soldRate: 0.40),
  ];

  /// 남은 자리 중 '남이 잡고 있는' 자리의 비율.
  ///
  /// 전체가 아니라 **남은 자리 기준**이다. 전체 비율로 잡으면 거의 다 팔린
  /// 구역(C)에서 남은 몇 석마저 선점중으로 덮여 매진으로 보인다.
  static const _heldShare = 0.12;

  /// 구역 번호 → 배치도. 구역 번호는 1 부터다(서버도 그렇다).
  static final Map<int, List<List<Seat?>>> seatRowsByZone = {
    for (var i = 0; i < _seeds.length; i++) i + 1: _generateRows(i + 1, i),
  };

  static final List<Zone> zones = [
    for (var i = 0; i < _seeds.length; i++)
      Zone(
        id: i + 1,
        name: _seeds[i].name,
        price: price,
        seatCount: rowCount * seatsPerRow,
        availableCount: _availableCountOf(i + 1),
        rowCount: rowCount,
        seatsPerRow: seatsPerRow,
      ),
  ];

  /// 서버와 같은 방식으로 좌석 번호를 만든다. 구역이 달라도 겹치지 않는다.
  static int seatIdOf(int zoneId, int row, int number) =>
      zoneId * 1000 + (row - 1) * seatsPerRow + number;

  static List<List<Seat?>> _generateRows(int zoneId, int seedIndex) {
    final random = Random(zoneId);
    return [
      for (var row = 1; row <= rowCount; row++)
        [
          for (var number = 1; number <= seatsPerRow; number++)
            Seat(
              id: seatIdOf(zoneId, row, number),
              row: row,
              number: number,
              status: _statusFor(seedIndex, row, random),
            ),
        ],
    ];
  }

  static SeatStatus _statusFor(int seedIndex, int row, Random random) {
    final seed = _seeds[seedIndex];
    final soldRate = seedIndex == 0
        // 앞열이 더 많이 팔린 상태를 만들어 실제 공연장처럼 보이게 한다.
        ? seed.soldRate + (1 - row / rowCount) * 0.35
        : seed.soldRate;

    final roll = random.nextDouble();
    if (roll < soldRate) return SeatStatus.sold;
    if (roll < soldRate + (1 - soldRate) * _heldShare) return SeatStatus.held;
    return SeatStatus.available;
  }

  static int _availableCountOf(int zoneId) => seatRowsByZone[zoneId]!.fold(
    0,
    (sum, row) => sum + row.where((seat) => seat?.isSelectable ?? false).length,
  );
}
