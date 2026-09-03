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
    required this.posterAsset,
    required this.ticketPrice,
    required this.bookingFee,
  });

  final String concertTitle;
  final DateTime performedAt;
  final String venue;
  final String seat;
  final String bookerName;

  /// 공연 포스터 이미지 경로. 서버 연동 시 URL로 바뀐다.
  final String posterAsset;

  /// 티켓 자체 가격(원).
  final int ticketPrice;

  /// 예매 수수료(원).
  final int bookingFee;

  /// 실제 결제되는 금액. 가격과 수수료가 바뀌어도 합계가 어긋나지 않게 여기서 계산한다.
  int get totalPrice => ticketPrice + bookingFee;
}
