/// 체결된 양도 한 건의 상태. 서버 `TradeStatus` 와 값이 같다.
///
/// 결제(코인 차감)와 소유권 이전(온체인)이 체결 응답 전에 끝나므로, 구매
/// 응답은 언제나 [confirmed] 로 온다(200). 결제 완료 화면의 배지가 이 값을
/// 읽지만, 값이 도중에 바뀌지는 않는다.
///
/// 그래도 [pending] · [failed] 를 남겨 둔다. 서버 enum 에 있는 값이고, 내
/// 거래 내역에는 동기 처리 전에 남은 기록이 섞여 올 수 있다.
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
