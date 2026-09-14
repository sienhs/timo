/// 티켓 한 장의 발행 상태. 서버 `ReservationStatus` 와 값이 같다.
///
/// 좌석 배정과 결제는 주문이 확정되는 순간 끝나고, 온체인 티켓 발행만 뒤따라
/// 일어난다. 그래서 이 값은 "결제됐는가" 가 아니라 **"티켓이 나왔는가"** 를
/// 가리킨다. 결제 직후에는 [pendingMint] 라 입장도 양도도 아직 안 된다.
///
/// ```
/// pendingMint ──(성공)──▶ minted ──(회원 취소)──▶ cancelled
///      └──(3회 실패)──▶ mintFailed ──(보상 환불)──▶ refunded
/// ```
enum TicketStatus {
  /// 결제는 끝났고 티켓 발행이 진행 중이다.
  pendingMint('PENDING_MINT'),

  /// 티켓이 나왔다. 입장·양도·취소가 되는 정상 상태다.
  minted('MINTED'),

  /// 발행 재시도를 모두 실패했다. 환불이 진행 중이다.
  mintFailed('MINT_FAILED'),

  /// 환불까지 끝났다. 좌석은 회수됐고 결제 금액은 돌아갔다.
  refunded('REFUNDED'),

  /// 회원이 취소했다. 티켓은 회수되고 정가가 전액 환원됐다.
  cancelled('CANCELLED');

  const TicketStatus(this.wireName);

  /// 서버가 주고받는 이름. 백엔드 enum 상수명과 같다.
  final String wireName;

  /// 서버 값을 읽는다.
  ///
  /// 모르는 값이 오면 [pendingMint] 로 본다. 서버에 상태가 하나 늘었을 때
  /// 목록 전체가 예외로 깨지는 것보다, 그 카드만 "발행 중" 으로 보수적으로
  /// 보이는 쪽이 낫다 — 발행 중은 입장·양도·취소가 모두 막힌 상태라 모르는
  /// 티켓으로 사고를 칠 여지가 없다.
  static TicketStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => pendingMint,
  );

  /// 티켓이 실제로 손에 있는 상태. 입장·양도·취소가 이때만 된다.
  bool get isUsable => this == minted;

  /// 발행을 기다리는 중.
  bool get isIssuing => this == pendingMint;

  /// 발행에 실패했다. 환불이 뒤따른다.
  bool get isFailed => this == mintFailed;

  /// 티켓이 사라진 상태. 목록에서 지우지 않고 회색 카드로 남겨 결과를 보여준다.
  bool get isVoided => this == refunded || this == cancelled;
}
