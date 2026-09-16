import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';
import 'mock_my_page_data.dart';

/// 충전을 기억해 두는 메모리 원장. 서버 없이 도는 `MockMyPageApi` 전용이다.
///
/// 충전이 잔액과 사용 내역에 반영되는 걸 화면 테스트가 확인할 수 있어야 해서,
/// 서버가 하는 일(충전분을 더하고 내역 한 줄을 쌓는 것)을 여기서 흉내 낸다.
/// 앱은 `HttpMyPageApi` 로 실제 지갑 API 를 보므로 이 원장을 쓰지 않는다.
class MockWalletLedger {
  MockWalletLedger({WalletSummary? initial, this.clock = DateTime.now})
    : _wallet = initial ?? MockMyPageData.wallet;

  /// 충전 내역에 찍을 시각을 읽는 함수. 테스트가 시각을 고정할 때 넘긴다.
  final DateTime Function() clock;

  WalletSummary _wallet;

  WalletSummary get wallet => _wallet;

  /// 충전분을 잔액에 더하고 내역 맨 앞에 한 줄을 끼운다. 충전 뒤의 지갑을
  /// 돌려주므로 화면은 응답만으로 새 잔액을 그릴 수 있다.
  WalletSummary charge(int amount) {
    final balance = _wallet.balance + amount;
    return _wallet = WalletSummary(
      balance: balance,
      transactions: [
        WalletTransaction(
          title: MockMyPageData.chargeTitle,
          amount: amount,
          balanceAfter: balance,
          occurredAt: clock(),
          source: MockMyPageData.chargeSource,
        ),
        ..._wallet.transactions,
      ],
    );
  }
}
