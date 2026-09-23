/// 티켓(온체인 발행) 한 장의 상태. 서버 `TicketStatus` 와 값이 같다. 예매 상태
/// (`ReservationStatus`)가 "이 자리를 샀는가" 라면 이건 그 표가 지금 어떤
/// 상태인가다. 내 티켓 목록(`GET /api/v1/tickets/me`)이 이 값을 준다.
///
/// ```
/// pendingMint ──(발행 성공)──▶ owned ──(입장)──▶ used
///      │                         ├──(회수)──▶ revoked
///      │                         └──(양도 등록)──▶ listed
///      └──(실패)──▶ mintFailed ──(보상 환불)──▶ refunded
/// ```
enum TicketStatus {
  /// 주문은 확정됐지만 온체인 발행은 아직. 결제 직후 몇 초 동안이다.
  pendingMint('PENDING_MINT'),

  /// 발행 시도가 실패했다. 서버가 보상 환불을 진행한다.
  mintFailed('MINT_FAILED'),

  /// 보상 환불까지 끝났다. 표는 없고 돈은 돌아왔다.
  refunded('REFUNDED'),

  /// 발행 완료, 정상 소유 중. 입장·취소·양도 등록이 되는 상태다.
  owned('OWNED'),

  /// 양도 마켓에 등록됐다. 팔리기 전까지 입장·취소가 막힌다.
  listed('LISTED'),

  /// 입장 처리가 끝났다. QR 을 다시 받아도 서버가 거절한다.
  used('USED'),

  /// 예매 취소 등으로 회수됐다.
  revoked('REVOKED'),

  /// 서버가 준 값을 앱이 모른다. 서버에 상태가 하나 늘었을 때만 나온다. 목록
  /// 전체가 깨지는 것보다 그 카드만 잠그는 쪽이 낫고, 회수됨으로 치면 거짓말이 된다.
  unknown('');

  const TicketStatus(this.wireName);

  /// 서버가 주고받는 이름. 백엔드 enum 상수명과 같다. [unknown] 은 서버에 없는
  /// 값이라 비어 있다.
  final String wireName;

  /// 서버 값을 읽는다. 모르는 값은 [unknown] 이다.
  static TicketStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => unknown,
  );

  /// 발행이 끝나 손에 있는 상태. 입장·취소·양도 등록의 전제다. 마켓에 올라가
  /// 있는지는 서버가 `listed` 를 따로 주므로 `MyTicket.isListed` 가 함께 본다.
  bool get isOwned => this == owned;

  /// 표가 사라진 상태. 목록에서 지우지 않고 회색 카드로 남겨 결과를 보여준다.
  bool get isVoided => this == revoked || this == refunded;
}
