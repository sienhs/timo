import 'ticket_order.dart';

/// 결제 화면이 완료 화면에 넘기는 것 — 화면에 그릴 주문 정보와, 발행 진행 상태를
/// 물어볼 예매 번호. [order] 는 서버 응답이 아니라 결제 화면이 그리던 값 그대로다.
/// [reservationId] 가 null 이면 서버에 주문을 만들지 않고 넘어온 것이라(예매 흐름
/// 밖에서 연 경우) 완료 화면은 발행 상태를 묻지 않고 "발행 중" 배지만 보여 준다.
class PlacedOrder {
  const PlacedOrder({required this.order, this.reservationId});

  final TicketOrder order;

  /// 서버가 만든 주문의 번호. 완료 화면이 이 번호로 발행 상태를 몇 초마다 묻는다.
  final int? reservationId;
}
