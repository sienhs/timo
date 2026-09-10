import '../models/signup_draft.dart';
import '../models/auth_tokens.dart';

/// 인증(회원가입·로그인) 화면이 서버에 요청하는 일 여섯 가지.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpAuthApi] 가 실제 서버에 요청하고,
/// 테스트와 로그인 화면(백엔드 API 미완)은 [MockAuthApi] 를 쓴다.
///
/// 반환 규칙:
/// - 정상 흐름에서 예상되는 결과(번호 불일치, 이미 쓰는 아이디)는 값으로
///   돌려준다. 화면이 `if` 한 줄로 처리할 수 있다.
/// - 네트워크 오류·서버 오류처럼 예상 밖의 실패는 `ApiException` 으로 던진다.
///   `message` 에 서버가 준 문구(ProblemDetail 의 errorMessage)나 네트워크
///   상황 문구가 들어 있어 화면은 그대로 보여주면 된다(api-response-convention).
///   같은 상태 코드 안에서 원인을 가를 때는 `exceptionName` 을 본다.
abstract class AuthApi {
  /// [phoneNumber] 로 인증번호를 보내고, 그 번호가 유효한 시간을 돌려준다.
  /// 화면은 이 값으로 남은 시간을 센다. 전화번호는 숫자만 ('01012345678').
  ///
  /// 발송 횟수 제한(1분 안에 재요청, 하루 5회)에 걸리면 429 예외.
  Future<Duration> requestVerificationCode(String phoneNumber);

  /// 인증번호가 맞으면 **인증 티켓**을, 틀리면 null 을 돌려준다.
  ///
  /// 티켓은 "이 번호는 본인 확인이 끝났다" 는 서버의 증표다. 가입 요청에 같이
  /// 실어 보내야 하며 30분 뒤 만료된다. 인증번호 만료(3분)·시도 횟수 초과는
  /// 틀린 것과 안내가 달라 예외로 던진다.
  Future<String?> verifyCode({
    required String phoneNumber,
    required String code,
  });

  Future<bool> isUsernameAvailable(String username);

  Future<bool> isNicknameAvailable(String nickname);

  /// 가입한다. [draft] 에는 인증 티켓까지 채워져 있어야 한다.
  ///
  /// 중복(409: 아이디·닉네임·전화번호)과 티켓 만료(400)는 예외로 던진다.
  /// 중복 확인을 통과했어도 그 사이 남이 채가면 409 가 날 수 있다.
  Future<AuthTokens> signUp(SignupDraft draft);

  /// 아이디·비밀번호가 맞으면 토큰을, 틀리면 null 을 돌려준다.
  ///
  /// 서버는 "아이디 없음" 과 "비밀번호 틀림" 을 구분해 주지 않는다. 구분하면
  /// 어떤 아이디가 가입돼 있는지 밖에서 알아낼 수 있어서다. 정지·탈퇴 계정(403)
  /// 은 입력이 틀린 게 아니라 예외로 던진다.
  Future<AuthTokens?> login({
    required String username,
    required String password,
  });
}
