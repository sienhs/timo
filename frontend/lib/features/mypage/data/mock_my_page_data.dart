import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';

/// 마이페이지 목업. 시안에 그려진 값 그대로다.
///
/// 지갑 API 가 서버에 아직 없어 `HttpMyPageApi` 도 지갑은 이걸 돌려준다.
/// API 가 생기면 그쪽 본문을 바꾸고 [wallet] 을 지운다. [profile] 은 화면
/// 테스트용이다 — 실제 앱은 `/members/me` 로 받는다.
class MockMyPageData {
  MockMyPageData._();

  static const profile = MemberProfile(memberId: 1, nickname: '엥간한 닉네임');

  /// 충전 내역 한 줄의 이름과 결제 경로. 시안의 사용 내역에 있는 문구 그대로다.
  /// [MockWalletLedger] 가 새 충전을 이 이름으로 쌓는다.
  static const chargeTitle = '머쉬룸 충전';
  static const chargeSource = '카카오페이';

  static final wallet = WalletSummary(
    balance: 123000,
    transactions: [
      WalletTransaction(
        title: '2026 REMIND: 리센느 콘서트 구매',
        amount: -176000,
        balanceAfter: 23400,
        occurredAt: DateTime(2026, 9, 12, 19, 42),
        source: '양도 마켓',
      ),
      WalletTransaction(
        title: chargeTitle,
        amount: 150000,
        balanceAfter: 199400,
        occurredAt: DateTime(2026, 9, 12, 19, 30),
        source: chargeSource,
      ),
      WalletTransaction(
        title: '2026 아이유 콘서트 구매',
        amount: -121000,
        balanceAfter: 49400,
        occurredAt: DateTime(2026, 9, 3, 14, 5),
        source: '양도 마켓',
      ),
      WalletTransaction(
        title: '판매 정산',
        amount: 98000,
        balanceAfter: 170400,
        occurredAt: DateTime(2026, 8, 28, 10, 12),
        source: '판매 등록 #2381',
      ),
    ],
  );
}
