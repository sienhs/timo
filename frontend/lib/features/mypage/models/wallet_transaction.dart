/// 코인(MSR) 거래 내역 한 건. [amount] 는 부호가 있는 정수다 — 지갑 API 가 종류
/// 필드 없이 부호로 잔액의 증가(충전·정산·환불)와 감소(구매)를 가른다.
class WalletTransaction {
  const WalletTransaction({
    required this.title,
    required this.amount,
    required this.balanceAfter,
    required this.occurredAt,
    required this.source,
  });

  /// 무엇에 쓰였는지. (예: `2026 아이유 콘서트 구매`, `버섯 충전`)
  final String title;

  /// 부호가 있는 변동액.
  final int amount;

  /// 이 거래 뒤의 잔액.
  final int balanceAfter;

  final DateTime occurredAt;

  /// 거래가 일어난 곳. (예: `양도 마켓`, `카카오페이`, `판매 등록 #2381`)
  final String source;

  /// 잔액이 늘어난 거래인지. 필터의 '+'가 이쪽, '-'가 줄어든 거래다.
  bool get isCredit => amount > 0;

  /// 서버 응답 한 줄. [occurredAt] 은 시간대 없는 문자열로 오고, 서버 시각대로
  /// 읽으면 되므로 변환 없이 그대로 파싱한다.
  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        title: json['title'] as String,
        amount: (json['amount'] as num).toInt(),
        balanceAfter: (json['balanceAfter'] as num).toInt(),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        source: json['source'] as String,
      );
}
