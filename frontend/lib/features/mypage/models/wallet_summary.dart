import 'wallet_transaction.dart';

/// 내 지갑. 잔액과 최근 거래 내역을 함께 든다.
///
/// 시안에서 두 카드(내 Mushroom · 사용 내역)로 나뉘어 있지만 둘은 같은
/// 원장에서 나오는 값이고 한쪽만 실패할 이유가 없어 한 번에 받는다.
class WalletSummary {
  const WalletSummary({required this.balance, required this.transactions});

  /// 사용 가능 잔액(MSR).
  final int balance;

  /// 최근 거래. 최신순.
  final List<WalletTransaction> transactions;
}
