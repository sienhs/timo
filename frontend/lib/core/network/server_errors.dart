/// 예매 흐름에서 서버가 실어 주는 예외 클래스 이름(ProblemDetail 의 `exception`).
/// 좌석 선점 409 처럼 같은 상태 코드 안에서 원인을 가를 때 문구 대신 이걸로
/// 비교한다. booking 과 payment 가 함께 쓰는 이름이라 core 에 둔다.
class BookingServerErrors {
  BookingServerErrors._();

  /// 잡으려는 자리를 남이 먼저 가져갔거나 이미 팔렸다(409). 어느 쪽인지는
  /// 서버가 알려주지 않는다(남의 선점 현황을 읽어 내는 통로가 되면 안 된다).
  static const seatNotHoldable = 'SeatNotHoldableException';

  /// 잡아 둔 자리가 없거나 시간이 지났다(409). 주문을 만들 때만 온다.
  static const seatNotHeld = 'SeatNotHeldException';

  /// 남이 잡고 있는 자리다(403). 주문을 만들 때만 온다.
  static const seatHoldNotOwned = 'SeatHoldNotOwnedException';

  /// 이 공연의 티켓을 이미 가지고 있다(409). 한 공연에 한 장이다.
  static const alreadyReserved = 'AlreadyReservedException';

  /// 예매 중인 공연이 아니다(409). 오픈 전·매진·종료·취소가 전부 여기로 온다.
  static const concertNotOnSale = 'ConcertNotOnSaleException';

  /// 이 공연의 보안문자를 통과하지 않았거나 통과한 지 5분이 지났다(403).
  /// 좌석 배치도를 받을 때만 온다. 보안문자를 다시 띄워 복구한다.
  static const captchaRequired = 'CaptchaRequiredException';

  /// 입력값이 틀렸다(400). 키는 이미 폐기됐다.
  static const captchaMismatch = 'CaptchaMismatchException';

  /// 키가 없거나 2분이 지났거나 이미 쓰였다(404). 없는 공연도 404 라 이름으로 가른다.
  static const captchaKeyNotFound = 'CaptchaKeyNotFoundException';

  /// 남에게 발급된 키다(403). 정상적인 앱에서는 나오지 않는다.
  static const captchaKeyOwnerMismatch = 'CaptchaKeyOwnerMismatchException';
}
