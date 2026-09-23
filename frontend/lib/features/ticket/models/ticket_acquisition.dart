/// 이 티켓이 내 것이 된 경로. 서버 `TicketAcquisition` 과 값이 같다. 양도로 받은
/// 티켓은 예매 행이 판 사람 것이라 예매 취소를 걸면 404 다 — 그래서 내 티켓
/// 목록(`GET /api/v1/tickets/me`)이 이 값을 함께 준다.
enum TicketAcquisition {
  /// 직접 예매했다. 예매 취소·주문 상세가 내 것이다.
  booking('BOOKING'),

  /// 양도 마켓에서 샀다. 예매 행은 판 사람 것이다.
  transfer('TRANSFER'),

  /// 서버가 준 값을 앱이 모른다. 취소를 여는 쪽으로 기울면 404 를 받게 되므로
  /// [booking] 처럼 다루지 않는다.
  unknown('');

  const TicketAcquisition(this.wireName);

  /// 서버가 주고받는 이름. 백엔드 enum 상수명과 같다.
  final String wireName;

  /// 서버 값을 읽는다. 모르는 값은 [unknown] 이다.
  static TicketAcquisition fromWire(Object? value) => values.firstWhere(
    (acquisition) => acquisition.wireName == value,
    orElse: () => unknown,
  );
}
