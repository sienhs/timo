import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/booking/models/performance.dart';
import 'package:timo/features/booking/models/seat.dart';
import 'package:timo/features/booking/models/seat_hold.dart';
import 'package:timo/features/booking/models/zone.dart';
import 'package:timo/features/booking/state/booking_controller.dart';
import 'package:timo/features/booking/state/ticket_order_adapter.dart';

/// 예매 상태를 결제 주문으로 옮기는 자리. **금액이 어디서 오는지**가 핵심이다.
///
/// 서버는 좌석 선점 응답에 그 자리의 값을 함께 준다. 배치도에서 받은 구역
/// 가격을 화면 사이로 들고 다니면 구역을 바꿔 다시 잡았을 때 어긋날 수 있어서,
/// 잡은 자리의 값을 그 자리에서 받아 쓴다.
void main() {
  final performance = Performance(
    title: '김필 단독 콘서트',
    venue: '고척돔',
    startAt: DateTime(2026, 10, 10, 19),
    bookingFee: 2000,
  );

  const zone = Zone(
    id: 1,
    name: '1층 A블록',
    price: 150000,
    seatCount: 200,
    availableCount: 199,
    rowCount: 10,
    seatsPerRow: 20,
  );

  const seat = Seat(id: 11, row: 1, number: 1, status: SeatStatus.available);

  SeatHold holdOf(int price) => SeatHold(
    seatId: seat.id,
    price: price,
    expiresAt: DateTime(2026, 9, 14, 20),
    heldAt: DateTime(2026, 9, 14, 19, 55),
  );

  BookingController controllerWith({SeatHold? hold}) {
    final controller = BookingController(performance: performance)
      ..selectSeat(zone, seat);
    if (hold != null) controller.holdSeat(hold);
    return controller;
  }

  test('자리를 잡았으면 선점 응답의 값을 결제 금액으로 쓴다', () {
    // 구역 가격(150,000)과 다른 값을 줘서 어느 쪽을 읽는지 가린다.
    final order = ticketOrderOf(controllerWith(hold: holdOf(120000)));

    expect(order, isNotNull);
    expect(order!.ticketPrice, 120000);
    expect(order.totalPrice, 122000);
  });

  test('아직 안 잡았으면 고른 구역의 값을 쓴다', () {
    // 결제 화면을 예매 흐름 밖에서 연 경우다.
    final order = ticketOrderOf(controllerWith());

    expect(order!.ticketPrice, 150000);
  });

  test('다른 자리를 고르면 앞서 잡은 값을 쓰지 않는다', () {
    // 자리를 새로 고르면 선점이 풀린다. 그때 옛 금액이 남아 있으면 안 된다.
    final controller = controllerWith(hold: holdOf(120000))
      ..selectSeat(
        zone,
        const Seat(id: 12, row: 1, number: 2, status: SeatStatus.available),
      );

    expect(ticketOrderOf(controller)!.ticketPrice, 150000);
  });

  test('고른 자리가 없으면 주문을 만들지 않는다', () {
    final order = ticketOrderOf(BookingController(performance: performance));

    expect(order, isNull);
  });
}
