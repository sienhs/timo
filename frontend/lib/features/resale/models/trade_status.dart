/// 체결된 양도 한 건의 진행 상태. 서버 `TradeStatus` 와 값이 같다.
///
/// 결제(코인 차감)와 소유권 이전(온체인)이 DB 트랜잭션 밖이라, 구매 응답은
/// 언제나 [pending] 으로 온다(202). 화면은 이 값이 [confirmed] 로 바뀌는지
/// 지켜본다 — 결제 완료 화면의 배지가 '티켓 양도 중' 과 '티켓 양도 완료' 로
/// 갈리는 기준이 이것이다.
enum TradeStatus {
  /// DB 상 체결은 끝났고 온체인 전송이 남았다.
  pending('PENDING'),

  /// 온체인 전송까지 끝났다.
  confirmed('CONFIRMED'),

  /// 온체인 전송이 실패했다. 시안에 없는 상태라 화면이 문구로만 알린다.
  failed('FAILED'),

  /// 서버가 준 값을 앱이 모른다. 아직 진행 중인 것으로 본다 — 끝났다고
  /// 단정해 '양도 완료' 를 띄우면 화면이 거짓말을 한다.
  unknown('');

  const TradeStatus(this.wireName);

  final String wireName;

  static TradeStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => unknown,
  );

  /// 더 지켜볼 필요가 있는 상태. 완료·실패는 더 바뀌지 않는다.
  bool get isSettling => this == pending || this == unknown;
}
