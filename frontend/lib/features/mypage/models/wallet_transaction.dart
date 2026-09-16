/// 코인(MSR) 거래 내역 한 건.
///
/// [amount] 는 부호가 있는 정수다. 충전·판매 정산·환불처럼 잔액이 늘면 양수,
/// 구매처럼 줄면 음수다. 종류를 따로 두지 않고 부호로 가르는 이유: 지갑 API 가
/// 아직 없어 서버가 종류를 어떤 이름으로 줄지 모른다. 부호는 어떤 응답에서도
/// 만들 수 있다.
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
