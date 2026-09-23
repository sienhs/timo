import '../models/member_profile.dart';
import '../models/wallet_summary.dart';

/// 마이페이지가 서버에 요청하는 일. 구현은 `HttpMyPageApi`·`MockMyPageApi`,
/// 실패는 `ApiException` 으로 던진다. 401 도 예외로 오지만 그 전에 인터셉터가
/// 세션을 비워 화면이 로그아웃 상태로 바뀐다.
abstract class MyPageApi {
  /// 로그인한 회원 본인의 정보. 누구인지는 토큰이 정하므로 인자가 없다.
  Future<MemberProfile> fetchProfile();

  /// 결제 화면에 찍을 **예매자 실명**. [fetchProfile] 과 같은 `/members/me` 를
  /// 부르지만 이름 하나만 꺼내 돌려준다. [MemberProfile] 에 실명을 넣지 않으려고
  /// 따로 둔다 — 그 모델은 화면이 살아 있는 동안 들고 있어 로그·스냅샷에 실릴 수 있다.
  Future<String> fetchBookerName();

  /// 잔액과 최근 거래 내역.
  Future<WalletSummary> fetchWallet();

  /// [amount] MSR 을 충전하고 충전 뒤의 지갑을 돌려준다. 새 지갑을 받으므로
  /// [fetchWallet] 을 다시 부를 필요가 없다. 금액 한도는 화면(`ChargeAmount`)이
  /// 먼저 거르고, 서버가 되돌려주면 `ApiException` 으로 온다.
  Future<WalletSummary> charge(int amount);
}
