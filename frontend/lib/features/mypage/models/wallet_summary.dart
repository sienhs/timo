import 'wallet_transaction.dart';

/// 내 지갑. 잔액과 최근 거래 내역을 함께 든다. 같은 원장에서 나오는 값이라
/// 서버도 조회·충전 응답을 이 한 덩어리로 내려준다.
class WalletSummary {
  const WalletSummary({required this.balance, required this.transactions});

  /// 사용 가능 잔액(MSR).
  final int balance;

  /// 최근 거래. 최신순, 서버가 최대 20건까지 준다.
  final List<WalletTransaction> transactions;

  factory WalletSummary.fromJson(Map<String, dynamic> json) => WalletSummary(
    balance: (json['balance'] as num).toInt(),
    transactions: (json['transactions'] as List<dynamic>)
        .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
