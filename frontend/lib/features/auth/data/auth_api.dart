import '../models/signup_draft.dart';
import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';

/// 인증(회원가입·로그인·로그아웃·재발급) 요청 여덟 가지. 앱은 [HttpAuthApi],
/// 테스트는 [MockAuthApi] 를 쓴다. 예상되는 결과(번호 불일치, 이미 쓰는 아이디)는
/// 값으로 돌려주고, 예상 밖의 실패는 `ApiException` 으로 던진다.
abstract class AuthApi {
  /// [phoneNumber] 로 인증번호를 보내고, 그 번호가 유효한 시간을 돌려준다.
  /// 전화번호는 숫자만('01012345678'). 발송 제한(1분 안 재요청, 하루 5회)이면
  /// 429 · 이미 가입된 번호면 문자 없이 409. 제한 검사가 먼저라 같은 번호로
  /// 다시 부르면 409 대신 429 가 온다.
  Future<Duration> requestVerificationCode(String phoneNumber);

  /// 인증번호가 맞으면 인증 티켓을, 틀리면 null 을 돌려준다. 티켓은 가입 요청에
  /// 같이 실어 보내야 하며 30분 뒤 만료된다. 인증번호 만료(3분)·시도 횟수 초과는
  /// 틀린 것과 안내가 달라 예외로 던진다.
  Future<String?> verifyCode({
    required String phoneNumber,
    required String code,
  });

  Future<bool> isUsernameAvailable(String username);

  Future<bool> isNicknameAvailable(String nickname);

  /// 가입한다. [draft] 에는 인증 티켓까지 채워져 있어야 한다. 중복(409: 아이디·
  /// 닉네임·전화번호)과 티켓 만료(400)는 예외로 던진다. 중복 확인을 통과했어도
  /// 그 사이 남이 채가면 409 가 날 수 있다.
  Future<AuthTokens> signUp(SignupDraft draft);

  /// 아이디·비밀번호가 맞으면 토큰을, 틀리면 null 을 돌려준다. 서버는 "아이디
  /// 없음" 과 "비밀번호 틀림" 을 구분해 주지 않는다. 정지·탈퇴 계정(403)은
  /// 예외로 던진다.
  Future<AuthTokens?> login({
    required String username,
    required String password,
  });

  /// 서버에 로그아웃을 알려 이 기기의 세션(리프레시 토큰)을 끊는다. 서버는 토큰이
  /// 틀려도 성공을 주므로 실패는 네트워크가 끊겼을 때만 난다. 액세스 토큰(JWT)은
  /// 서버가 끊지 못해 기기 토큰을 지우는 [AuthSession.signOut] 이 더 중요하다.
  Future<void> logout(String refreshToken);

  /// 리프레시 토큰으로 새 액세스 토큰을 받는다. 화면이 아니라 `AuthInterceptor`
  /// 가 만료 때 부른다. 리프레시 토큰은 회전하지 않아 갖고 있던 것을 계속 쓴다.
  /// 위조·끊김·만료 어느 쪽이든 서버는 401 하나로 주므로 실패는 전부 예외다.
  Future<ReissuedAccessToken> reissue(String refreshToken);
}
