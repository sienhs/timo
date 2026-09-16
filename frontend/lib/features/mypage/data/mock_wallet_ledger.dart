import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';
import 'mock_my_page_data.dart';

/// 충전을 기억해 두는 메모리 원장.
///
/// 지갑 API 가 서버에 아직 없다(요구사항 #21, PG 모의 연동). 충전이 잔액에
/// 반영되는 걸 눈으로 볼 수 있어야 화면이 맞는지 알 수 있어서, 서버 대신
/// 여기에 쌓아 둔다. 앱을 끄면 [MockMyPageData.wallet] 로 돌아간다.
///
/// 실제 API 가 생기면 `HttpMyPageApi` 가 이 원장 대신 서버를 보고, 이 클래스는
/// 테스트용 목만 남는다.
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
