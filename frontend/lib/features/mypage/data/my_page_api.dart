import '../models/member_profile.dart';
import '../models/wallet_summary.dart';

/// 마이페이지가 서버에 요청하는 일 두 가지.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpMyPageApi] 가 실제 서버에
/// 요청하고, 테스트는 [MockMyPageApi] 를 쓴다. 홈의 `HomeApi` 와 같은 구조다.
///
/// 반환 규칙: 성공하면 값을, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 로그인이 풀린 상태(401)도 예외로 오지만, 그 전에 인터셉터가
/// 세션을 비워 화면이 로그아웃 상태로 바뀐다.
abstract class MyPageApi {
  /// 로그인한 회원 본인의 정보. 누구인지는 토큰이 정하므로 인자가 없다.
  Future<MemberProfile> fetchProfile();

  /// 잔액과 최근 거래 내역.
  Future<WalletSummary> fetchWallet();
}
