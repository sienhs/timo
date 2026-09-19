/// 주문(예매) 한 건의 상태. 서버 `ReservationStatus` 와 값이 같다.
///
/// 결제와 좌석 배정은 주문이 확정되는 순간 끝난다. 그래서 이 값은 **"이 자리를
/// 샀는가"** 만 가리킨다.
///
/// ```
/// paid ──(회원 취소)──▶ cancelled
/// ```
///
/// **온체인 발행 진행 상태는 여기에 없다.** 발행 중 · 발행 실패 · 보상 환불은
/// 주문이 아니라 티켓 쪽 관심사라 서버가 주문 상태에서 뺐다(백엔드
/// `ReservationStatus` 주석). 티켓 쪽 상태는 `TicketStatus` 가 따로 든다.
///
/// 이름이 `TicketStatus` 였던 것을 바꿨다. 실제로는 예매 상태인데 티켓 상태로
/// 불려서, 서버가 진짜 티켓 상태를 내주기 시작하자 이름이 부딪혔다.
enum ReservationStatus {
  /// 결제가 끝났다. 이 주문이 자리를 붙들고 있고, 입장·취소가 되는 정상 상태다.
  paid('PAID'),

  /// 회원이 취소했다. 티켓은 회수되고 정가가 전액 환원됐다.
  ///
  /// 그 자리는 곧바로 예매 가능으로 돌아가지 않는다. 취소 시점에 정해진
  /// 3분 1초~15분 뒤의 랜덤한 시각까지는 배치도에 선점과 똑같이 HELD 로
  /// 보이고, 그 시각이 지나면 누구나 잡을 수 있다(S15P21D206-347).
  cancelled('CANCELLED'),

  /// 서버가 준 값을 앱이 모른다. 서버에 상태가 하나 늘었을 때만 나온다.
  ///
  /// 목록 전체가 예외로 깨지는 것보다 그 카드만 잠그는 쪽이 낫다. 취소됨으로
  /// 치지 않는 이유는, 취소하지 않은 티켓에 "예매를 취소했어요" 가 붙으면
  /// 화면이 거짓말을 하기 때문이다.
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
