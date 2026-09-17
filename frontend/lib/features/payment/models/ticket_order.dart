/// 티켓 한 건의 예매·결제 정보.
///
/// 화면 위젯은 이 객체만 받아 그린다. 값이 서버에서 왔는지 더미인지는 모르게 둔다.
class TicketOrder {
  const TicketOrder({
    required this.concertTitle,
    required this.performedAt,
    required this.venue,
    required this.seat,
    required this.bookerName,
    this.posterUrl,
    required this.ticketPrice,
  });

  final String concertTitle;
  final DateTime performedAt;
  final String venue;
  final String seat;
  final String bookerName;

  /// 공연 포스터 주소. 포스터가 없는 공연이면 null 이다.
  final String? posterUrl;

  /// 티켓 가격(원). 실제 결제되는 금액이기도 하다.
  ///
  /// 수수료가 없어 합계를 따로 두지 않는다. 서버가 차감하는 것도 이 정가
  /// 하나다(`Performance` 주석).
  final int ticketPrice;
}
