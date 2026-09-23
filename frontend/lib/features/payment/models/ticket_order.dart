/// 티켓 한 건의 예매·결제 정보. 화면 위젯은 이 객체만 받아 그린다.
class TicketOrder {
  const TicketOrder({
    required this.concertTitle,
    required this.performedAt,
    required this.venue,
    required this.seat,
    this.bookerName,
    this.posterUrl,
    required this.ticketPrice,
  });

  final String concertTitle;
  final DateTime performedAt;
  final String venue;
  final String seat;

  /// 예매자 실명. 자리는 잡혔는데 이름 요청만 실패하면 null 이고, 그때 요약 카드는
  /// '예매자 성함' 줄을 아예 그리지 않는다 — 아무 이름이나 채우거나 결제를 막는
  /// 것보다 낫다.
  final String? bookerName;

  /// 공연 포스터 주소. 포스터가 없는 공연이면 null 이다.
  final String? posterUrl;

  /// 티켓 가격(원). 실제 결제되는 금액이기도 하다. 수수료가 없어 합계를 따로 두지
  /// 않는다(`Performance` 주석).
  final int ticketPrice;
}
