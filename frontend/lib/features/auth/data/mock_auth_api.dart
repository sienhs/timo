import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/signup_draft.dart';
import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';
import 'auth_api.dart';

/// 서버 없이 쓰는 가짜 [AuthApi]. 화면 테스트가 쓴다. 고정값([invalidCode]·
/// [takenUsernames]·[takenNicknames]·[wrongPassword] 등)만 실패하고 그 외 입력은
/// 모두 성공한다. 응답마다 [latency] 만큼 기다린다(테스트는 `Duration.zero`).
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

  /// 이 토큰으로 로그아웃하면 연결 오류 예외를 던진다. 실제 서버는 로그아웃을
  /// 실패로 돌려주지 않아, 흉내 낼 실패는 "서버에 닿지 못함" 하나뿐이다. 화면
  /// 테스트가 "서버에 못 알려도 로그아웃은 된다" 를 볼 때 쓴다.
  static const offlineRefreshToken = 'mock-offline';

  /// 이 토큰으로 재발급하면 서버가 거절한 것처럼 401 예외를 던진다.
  /// "재발급까지 실패하면 로그아웃된다" 를 볼 때 쓴다.
  static const rejectedRefreshToken = 'mock-rejected';

  /// 재발급이 돌려주는 새 액세스 토큰. 원래 토큰([tokens])과 값이 달라야
  /// 테스트가 "갈아끼워졌는지" 를 구분할 수 있다.
  static const reissuedAccessToken = 'mock-access-token-2';

  /// 가입·로그인 응답 흉내. 서버에 보내지 않으므로 값은 아무것이어도 된다.
  static const tokens = AuthTokens(
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
  Future<AuthTokens> signUp(SignupDraft draft) async {
    await _respond();
    return tokens;
  }

  @override
  Future<AuthTokens?> login({
    required String username,
    required String password,
  }) async {
    await _respond();
    return password == wrongPassword ? null : tokens;
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _respond();
    if (refreshToken == offlineRefreshToken) {
      throw const ApiException('인터넷 연결을 확인해주세요.');
    }
  }

  @override
  Future<ReissuedAccessToken> reissue(String refreshToken) async {
    await _respond();
    if (refreshToken == rejectedRefreshToken) {
      throw ApiException(
        '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
        status: 401,
        errorCode: AuthErrorCodes.tokenInvalid,
      );
    }
    return const ReissuedAccessToken(
      accessToken: reissuedAccessToken,
      expiresIn: Duration(minutes: 30),
    );
  }
}
