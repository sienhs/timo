/// '결제하기' 가 서버에 주문을 만들 때 보내는 것 — 어느 공연의 어느 자리인가.
/// 백엔드 `CreateReservationRequestDto` 의 두 필드와 같다. 값은 예매 흐름의
/// 상태(`BookingController.concertId` · `SeatHold.seatId`)에서 오고, 흐름 밖에서
/// 연 결제 화면에는 없어(null) 그때 결제하기는 서버를 부르지 않는다.
class OrderTarget {
  const OrderTarget({required this.concertId, required this.seatId});

  final int concertId;

  /// 서버에 잡아 둔(선점한) 좌석 번호. 요청자가 유효하게 잡고 있는 자리여야
  /// 서버가 주문으로 바꿔 준다.
  final int seatId;
}
