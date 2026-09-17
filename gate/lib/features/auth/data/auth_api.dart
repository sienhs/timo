import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';

/// 인증(로그인·로그아웃·재발급) 요청 세 가지.
///
/// 팬 앱 `AuthApi` 에서 게이트에 필요한 것만 남겼다 — 회원가입·인증번호·중복
/// 확인은 없다. 게이트는 이미 있는 관리자 계정으로만 로그인한다.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpAuthApi] 가 실제 서버에 요청하고,
/// 테스트와 서버 없는 실행은 [MockAuthApi] 를 쓴다.
///
/// 반환 규칙:
/// - 정상 흐름에서 예상되는 결과(아이디·비밀번호 틀림)는 값(null)으로 돌려준다.
/// - 네트워크 오류·서버 오류처럼 예상 밖의 실패는 `ApiException` 으로 던진다.
///   `message` 에 서버가 준 문구나 네트워크 상황 문구가 들어 있어 화면은 그대로
///   보여주면 된다.
abstract class AuthApi {
  /// 아이디·비밀번호가 맞으면 토큰을, 틀리면 null 을 돌려준다.
  ///
  /// 서버는 "아이디 없음" 과 "비밀번호 틀림" 을 구분해 주지 않는다. 정지·탈퇴
  /// 계정(403)은 입력이 틀린 게 아니라 예외로 던진다.
  ///
  /// **관리자인지는 여기서 가르지 않는다.** 서버 로그인 API 는 역할을 보지
  /// 않고 누구든 로그인시킨다. 받은 토큰의 클레임을 화면이 `AccessTokenClaims`
  /// 로 읽어 관리자가 아니면 세션에 담지 않는다.
  Future<AuthTokens?> login({
    required String username,
    required String password,
  });

  /// 서버에 로그아웃을 알려 이 기기의 세션(리프레시 토큰)을 끊는다.
  ///
  /// 서버는 실패를 돌려주지 않는다. 토큰이 틀리거나 이미 끊긴 세션이어도 성공이다.
  /// 실패는 네트워크가 끊겼을 때만 나며, 그때도 기기 토큰은 지워야 하므로
  /// 무시할지는 부르는 쪽이 정한다.
  Future<void> logout(String refreshToken);

  /// 리프레시 토큰으로 **새 액세스 토큰**을 받는다.
  ///
  /// 화면이 부르는 요청이 아니다. 로그인이 필요한 API 가 "토큰이 만료됐다"고
  /// 할 때 `AuthInterceptor` 가 사용자 모르게 부른다. 실패는 전부 예외다 —
  /// 서버는 위조·폐기·만료를 401 하나로 묶어 준다.
  Future<ReissuedAccessToken> reissue(String refreshToken);
}
