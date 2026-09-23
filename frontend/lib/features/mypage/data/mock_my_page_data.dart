import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import '../models/wallet_transaction.dart';

/// 마이페이지 목업. 시안에 그려진 값 그대로다. 화면 테스트용이다.
class MockMyPageData {
  MockMyPageData._();

  static const profile = MemberProfile(memberId: 1, nickname: '엥간한 닉네임');

  /// 본인인증으로 확인된 실명. 결제 화면의 '예매자 성함' 에 찍힌다. 실명은 모델에
  /// 담지 않고 필요한 화면이 그때만 꺼내 쓰므로 [profile] 에는 없다.
  static const bookerName = '홍길동';

  /// 충전 내역 한 줄의 이름과 결제 경로. 시안의 사용 내역에 있는 문구 그대로다.
  /// [MockWalletLedger] 가 새 충전을 이 이름으로 쌓는다.
  static const chargeTitle = '버섯 충전';
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
