/// 주문(예매) 한 건의 상태. 서버 `ReservationStatus` 와 값이 같다. 결제와 좌석
/// 배정은 주문 확정 순간 끝나므로 이 값은 "이 자리를 샀는가" 만 가리킨다.
/// 온체인 발행 진행 상태는 티켓 쪽 관심사라 여기 없고 `TicketStatus` 가 든다.
enum ReservationStatus {
  /// 결제가 끝났다. 이 주문이 자리를 붙들고 있고, 입장·취소가 되는 정상 상태다.
  paid('PAID'),

  /// 회원이 취소했다. 티켓은 회수되고 정가가 전액 환원됐다. 그 자리는 취소 시점에
  /// 정해진 3분 1초~15분 뒤의 랜덤한 시각까지 HELD 로 보이다가 풀린다.
  cancelled('CANCELLED'),

  /// 서버가 준 값을 앱이 모른다. 서버에 상태가 하나 늘었을 때만 나온다. 목록
  /// 전체가 깨지는 것보다 그 카드만 잠그는 쪽이 낫고, 취소됨으로 치면 거짓말이 된다.
  unknown('');

  const ReservationStatus(this.wireName);

  /// 서버가 주고받는 이름. 백엔드 enum 상수명과 같다. [unknown] 은 서버에 없는
  /// 값이라 비어 있다.
  final String wireName;

  /// 서버 값을 읽는다. 모르는 값은 [unknown] 이다.
  static ReservationStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => unknown,
  );

  /// 티켓이 실제로 손에 있는 상태. 입장·취소가 이때만 된다.
  bool get isUsable => this == paid;

  /// 티켓이 사라진 상태. 목록에서 지우지 않고 회색 카드로 남겨 결과를 보여준다.
  bool get isVoided => this == cancelled;
}
