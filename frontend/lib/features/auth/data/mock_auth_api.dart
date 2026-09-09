import '../constants.dart';
import '../models/signup_draft.dart';
import '../models/signup_result.dart';
import 'auth_api.dart';

/// 서버 없이 쓰는 가짜 [AuthApi]. 화면 테스트와, 백엔드 API 가 아직 없는
/// 로그인 화면이 쓴다.
///
/// 오류 화면도 눈으로 보고 테스트할 수 있도록 실패하는 값을 고정해 둔다.
/// 그 외 입력은 모두 성공한다.
/// - 인증번호 [invalidCode] 는 틀린 번호. 맞으면 [mockTicket] 을 돌려준다
/// - 아이디 [takenUsernames], 닉네임 [takenNicknames] 는 이미 사용 중
/// - 로그인 비밀번호 [wrongPassword] 는 틀린 비밀번호(아이디는 무엇이든)
///
/// 응답마다 [latency] 만큼 기다려 실제 서버처럼 로딩 상태가 보이게 한다.
/// 테스트에서는 `Duration.zero` 를 넣어 바로 응답받는다.
class MockAuthApi implements AuthApi {
  const MockAuthApi({this.latency = AuthMetrics.mockLatency});

  final Duration latency;

  static const invalidCode = '000000';
  static const mockTicket = 'mock-verification-ticket';

  /// 발송 응답의 유효 시간. 실제 서버와 같은 3분.
  static const codeValidity = AuthMetrics.codeValidity;
  static const takenUsernames = {'timo', 'admin'};
  static const takenNicknames = {'티모'};
  static const wrongPassword = 'wrong1234';

  /// 가입 응답 흉내. 토큰은 저장하지 않으므로 값은 아무것이어도 된다.
  static const signupResult = SignupResult(
    memberId: 1,
    accessToken: 'mock-access-token',
    refreshToken: 'mock-refresh-token',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  Future<void> _respond() => Future<void>.delayed(latency);

  @override
  Future<Duration> requestVerificationCode(String phoneNumber) async {
    await _respond();
    return codeValidity;
  }

  @override
  Future<String?> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    await _respond();
    return code == invalidCode ? null : mockTicket;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await _respond();
    return !takenUsernames.contains(username);
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    await _respond();
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<SignupResult> signUp(SignupDraft draft) async {
    await _respond();
    return signupResult;
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    await _respond();
    return password != wrongPassword;
  }
}
