import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';
import 'auth_api.dart';

/// 서버 없이 쓰는 가짜 [AuthApi]. 화면 테스트와 `--dart-define=AUTH_API=mock`
/// 실행이 쓴다.
///
/// 계정은 아이디로 가른다. 비밀번호는 [wrongPassword] 만 틀린 것으로 친다:
/// - 아이디 [adminUsername] → 관리자 토큰. 로그인이 된다
/// - 그 외 아이디 → 팬(USER) 토큰. 아이디·비밀번호는 맞지만 관리자가 아니라 막힌다
/// - 비밀번호 [wrongPassword] → 아이디가 무엇이든 null (틀림)
///
/// 토큰은 서명 없는 가짜 JWT 다([fakeAccessToken]). 앱이 읽는 건 `roles`
/// 클레임뿐이라 그것만 맞으면 된다.
///
/// 응답마다 [latency] 만큼 기다려 실제 서버처럼 로딩 상태가 보이게 한다.
/// 테스트에서는 `Duration.zero` 를 넣어 바로 응답받는다.
class MockAuthApi implements AuthApi {
  const MockAuthApi({this.latency = AuthMetrics.mockLatency});

  final Duration latency;

  static const adminUsername = 'admin';
  static const wrongPassword = 'wrong1234';

  /// 이 토큰으로 로그아웃하면 연결 오류 예외를 던진다. "서버에 못 알려도
  /// 로그아웃은 된다" 를 볼 때 쓴다.
  static const offlineRefreshToken = 'mock-offline';

  /// 이 토큰으로 재발급하면 서버가 거절한 것처럼 401 예외를 던진다.
  static const rejectedRefreshToken = 'mock-rejected';

  /// 관리자 계정의 로그인 응답 흉내.
  static final adminTokens = AuthTokens(
    memberId: 1,
    accessToken: fakeAccessToken(memberId: 1, roles: const [AuthRoles.admin]),
    refreshToken: 'mock-refresh-token',
    accessTokenExpiresIn: const Duration(minutes: 30),
  );

  /// 팬 계정의 로그인 응답 흉내. 서버는 역할을 보지 않고 로그인시켜 준다.
  static final userTokens = AuthTokens(
    memberId: 2,
    accessToken: fakeAccessToken(memberId: 2, roles: const ['USER']),
    refreshToken: 'mock-refresh-token-user',
    accessTokenExpiresIn: const Duration(minutes: 30),
  );

  /// 재발급이 돌려주는 새 액세스 토큰. 원래 토큰과 값이 달라야 테스트가
  /// "갈아끼워졌는지" 를 구분할 수 있다.
  static final reissuedAccessToken = fakeAccessToken(
    memberId: 1,
    roles: const [AuthRoles.admin],
    tag: 'reissued',
  );

  /// 서버가 만드는 모양(`header.payload.signature`)의 가짜 JWT.
  ///
  /// 서명 자리는 아무 글자다 — 앱은 서명을 검증하지 않고(못 하고) 본문의
  /// `roles` 만 읽는다. [tag] 는 같은 역할의 토큰을 서로 다르게 만들 때 쓴다.
  static String fakeAccessToken({
    required int memberId,
    required List<String> roles,
    String tag = '',
  }) {
    String encode(Map<String, Object> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final header = encode({'alg': 'HS256', 'typ': 'JWT'});
    final payload = encode({'sub': '$memberId', 'roles': roles, 'tag': tag});
    return '$header.$payload.mock-signature';
  }

  Future<void> _respond() => Future<void>.delayed(latency);

  @override
  Future<AuthTokens?> login({
    required String username,
    required String password,
  }) async {
    await _respond();
    if (password == wrongPassword) return null;
    return username == adminUsername ? adminTokens : userTokens;
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
      throw const ApiException(
        '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
        status: 401,
        errorCode: AuthErrorCodes.tokenInvalid,
      );
    }
    return ReissuedAccessToken(
      accessToken: reissuedAccessToken,
      expiresIn: const Duration(minutes: 30),
    );
  }
}
