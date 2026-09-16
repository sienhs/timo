/// 코인(MSR) 거래 내역 한 건.
///
/// [amount] 는 부호가 있는 정수다. 충전·판매 정산·환불처럼 잔액이 늘면 양수,
/// 구매처럼 줄면 음수다. 종류를 따로 두지 않고 부호로 가르는 이유: 지갑 API 가
/// 종류 필드를 주지 않고 부호 하나로만 충전과 사용을 구분한다.
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

  /// 잔액이 늘어난 거래인지. 필터의 '충전' 이 이쪽, '사용' 이 반대쪽이다.
  bool get isCredit => amount > 0;

  /// 서버 응답 한 줄.
  ///
  /// [occurredAt] 은 시간대 없는 문자열(`2026-09-16T13:50:01.123456`)로 온다.
  /// 서버 시각대로 읽으면 되므로 변환 없이 그대로 파싱한다.
  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        title: json['title'] as String,
        amount: (json['amount'] as num).toInt(),
        balanceAfter: (json['balanceAfter'] as num).toInt(),
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        source: json['source'] as String,
      );
}

/// 사용 내역 필터. 순서가 시안의 세그먼트 순서다.
enum TransactionFilter {
  all('전체'),
  credit('충전'),
  debit('사용');

  const TransactionFilter(this.label);

  final String label;

  bool accepts(WalletTransaction transaction) => switch (this) {
    TransactionFilter.all => true,
    TransactionFilter.credit => transaction.isCredit,
    TransactionFilter.debit => !transaction.isCredit,
  };
}
