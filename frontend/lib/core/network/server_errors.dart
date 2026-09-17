/// 예매 흐름에서 서버가 실어 주는 예외 클래스 이름(ProblemDetail 의 `exception`).
///
/// **같은 상태 코드 안에서 원인을 가를 때 쓴다.** 좌석 선점의 409 는 자리를
/// 뺏긴 것·이미 이 공연 티켓이 있는 것·판매 중이 아닌 공연 셋 중 하나인데,
/// 사용자가 할 일이 전부 다르다. 셋을 한 문구로 뭉치면 다른 자리를 아무리
/// 골라도 같은 안내만 반복해서, 앱이 거짓말을 하는 것처럼 보인다.
///
/// 문구로 비교하지 않는 이유는 `ApiException.exceptionName` 주석에 있다 —
/// 서버가 문구를 다듬으면 조용히 어긋난다. 게다가 서버 문구에는
/// `(concertId=3)` 같은 디버깅용 꼬리가 붙어 있어 그대로 보여줄 것도 못 된다.
///
/// **`features` 가 아니라 여기 두는 이유.** 좌석 화면(booking)과 결제
/// 화면(payment)이 아래 이름 중 둘을 함께 본다. 예매 쪽이 결제 쪽을 참조하는
/// 한 방향 구조라, 공통 상수를 둘 중 한쪽에 두면 반대 방향 참조가 생겨 두
/// 도메인이 서로 물게 된다.
///
/// 인증 실패는 `AuthServerErrors` 가 따로 들고 있다. 그쪽은 가입·로그인
/// 화면만 쓰므로 도메인 안에 둔다.
class BookingServerErrors {
  BookingServerErrors._();

  /// 잡으려는 자리를 남이 먼저 가져갔거나 이미 팔렸다(409).
  ///
  /// 둘 중 어느 쪽인지는 서버가 알려주지 않는다. 좌석을 하나씩 찔러 남의 선점
  /// 현황을 읽어 내는 통로가 되면 안 되기 때문이다.
  static const seatNotHoldable = 'SeatNotHoldableException';

  /// 잡아 둔 자리가 없거나 시간이 지났다(409). 주문을 만들 때만 온다.
  static const seatNotHeld = 'SeatNotHeldException';

  /// 남이 잡고 있는 자리다(403). 주문을 만들 때만 온다.
  static const seatHoldNotOwned = 'SeatHoldNotOwnedException';

  /// 이 공연의 티켓을 이미 가지고 있다(409). 한 공연에 한 장이다.
  static const alreadyReserved = 'AlreadyReservedException';

  /// 예매 중인 공연이 아니다(409). 오픈 전·매진·종료·취소가 전부 여기로 온다.
  static const concertNotOnSale = 'ConcertNotOnSaleException';
}
