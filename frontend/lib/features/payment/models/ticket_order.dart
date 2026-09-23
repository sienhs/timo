/// 티켓 한 건의 예매·결제 정보.
///
/// 화면 위젯은 이 객체만 받아 그린다. 값이 서버에서 왔는지 더미인지는 모르게 둔다.
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

  /// 예매자 실명. 못 받았으면 null 이고, 그때 요약 카드는 '예매자 성함' 줄을
  /// 아예 그리지 않는다.
  ///
  /// 받아 오지 못하는 경우가 있다. 자리는 잡혔는데 이름 요청만 실패한 때다
  /// (`SeatSelectionScreen._onCheckout`). 그 자리에 아무 이름이나 채우면 남의
  /// 이름을 자기 결제 화면에서 보게 되고, 결제를 막으면 잡아 둔 자리를 날린다.
  /// 줄 하나를 비우는 쪽이 둘 다보다 낫다.
  final String? bookerName;

  /// 공연 포스터 주소. 포스터가 없는 공연이면 null 이다.
  final String? posterUrl;

  /// 티켓 가격(원). 실제 결제되는 금액이기도 하다.
  ///
  /// 수수료가 없어 합계를 따로 두지 않는다. 서버가 차감하는 것도 이 정가
  /// 하나다(`Performance` 주석).
  final int ticketPrice;
}
