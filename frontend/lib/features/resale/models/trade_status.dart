/// 체결된 양도 한 건의 상태. 서버 `TradeStatus` 와 값이 같다. 결제와 소유권
/// 이전이 응답 전에 끝나 구매 응답은 언제나 [confirmed] 다. [pending] · [failed]
/// 는 서버 enum 에 있고 내 거래 내역에 섞여 올 수 있어 남겨 둔다.
enum TradeStatus {
  /// DB 상 체결만 끝난 상태. 동기 처리 전의 기록에만 남아 있다.
  pending('PENDING'),

  /// 온체인 전송까지 끝났다.
  confirmed('CONFIRMED'),

  /// 온체인 전송이 실패했다. 시안에 없는 상태라 화면이 문구로만 알린다.
  failed('FAILED'),

  /// 서버가 준 값을 앱이 모른다. '양도 완료' 로 단정하지 않는다 — 모르는
  /// 값에 완료를 박으면 화면이 거짓말을 한다.
  unknown('');

  const TradeStatus(this.wireName);

  final String wireName;

  static TradeStatus fromWire(Object? value) => values.firstWhere(
    (status) => status.wireName == value,
    orElse: () => unknown,
  );
}
