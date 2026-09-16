import '../constants.dart';
import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import 'mock_my_page_data.dart';
import 'mock_wallet_ledger.dart';
import 'my_page_api.dart';

/// 서버 없이 쓰는 가짜 [MyPageApi]. 화면 테스트가 쓴다.
///
/// 응답마다 [latency] 만큼 기다려 실제 서버처럼 로딩 상태가 보이게 한다.
/// 테스트에서 기다릴 필요가 없으면 `Duration.zero` 를 넣는다.
class MockMyPageApi implements MyPageApi {
  const MockMyPageApi({this.latency = MyPageMetrics.mockLatency, this.ledger});

  final Duration latency;

  /// 충전을 기억해 두는 원장. 안 넘기면 충전 결과를 계산해 돌려만 주고 다음
  /// [fetchWallet] 에는 반영하지 않는다 — 충전 화면 하나만 보는 테스트는 그걸로
  /// 충분하고, 충전 뒤 마이페이지 잔액까지 보는 테스트가 원장을 넘긴다.
  /// (넘기지 않으면 `const` 로 만들 수 있어 기존 호출부가 그대로 쓴다.)
  final MockWalletLedger? ledger;

  /// 지연이 0 이면 타이머를 만들지 않는다. 0 짜리 타이머도 타이머라, 프레임을
  /// 한 번만 그리는 위젯 테스트가 끝날 때 "아직 남은 타이머" 로 잡힌다.
  Future<void> _respond() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<MemberProfile> fetchProfile() async {
    await _respond();
    return MockMyPageData.profile;
  }

  @override
  Future<WalletSummary> fetchWallet() async {
    await _respond();
    return ledger?.wallet ?? MockMyPageData.wallet;
  }

  @override
  Future<WalletSummary> charge(int amount) async {
    await _respond();
    return (ledger ?? MockWalletLedger()).charge(amount);
  }
}
