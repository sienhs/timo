import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';
import 'auth_api.dart';
import 'device_id.dart';

/// 백엔드 인증 API(`/api/v1/auth`)에 실제로 요청하는 [AuthApi].
///
/// 팬 앱과 같은 서버, 같은 주소를 쓴다. 어느 주소에 무엇을 보내고 응답에서
/// 무엇을 꺼내는지만 안다. 서버 주소·시간 제한·로그는 [ApiClient] 가, 실패
/// 응답을 화면용 문구로 바꾸는 일은 [ApiException] 이 맡는다.
///
/// [dio] 와 [deviceId] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아
/// [ApiClient.dio] 와 [DeviceId.value] 를 쓴다.
class HttpAuthApi implements AuthApi {
  HttpAuthApi({Dio? dio, String? deviceId})
    : _dio = dio ?? ApiClient.dio,
      _deviceId = deviceId ?? DeviceId.value;

  static const basePath = '/api/v1/auth';

  /// 기기 식별자 헤더. 백엔드 AuthController 와 이름이 같다. 서버가 (회원, 기기)
  /// 한 쌍으로 세션을 두므로 로그인·로그아웃·재발급 모두 같은 값을 보낸다.
  static const deviceIdHeader = 'X-Device-Id';

  final Dio _dio;
  final String _deviceId;

  Options get _deviceOptions => Options(headers: {deviceIdHeader: _deviceId});

  @override
  Future<AuthTokens?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _guard(
        () => _dio.post<dynamic>(
          '$basePath/login',
          data: {'username': username, 'password': password},
          options: _deviceOptions,
        ),
      );
      return AuthTokens.fromJson(_body(response));
    } on ApiException catch (e) {
      // 아이디 없음·비밀번호 틀림은 정상 흐름에서 예상되는 결과라 null. 정지·
      // 탈퇴 계정(403)과 네트워크 실패는 화면이 다르게 안내해야 하므로 예외로 둔다.
      if (e.exceptionName == AuthServerErrors.loginFailed) return null;
      rethrow;
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    // 응답은 204 로 본문이 없다. _body 를 타면 JSON 객체가 아니라서 예외가
    // 나므로 응답을 읽지 않는다.
    await _guard(
      () => _dio.post<dynamic>(
        '$basePath/logout',
        data: {'refreshToken': refreshToken},
        options: _deviceOptions,
      ),
    );
  }

  @override
  Future<ReissuedAccessToken> reissue(String refreshToken) async {
    // 인증 주소라 인터셉터가 액세스 토큰을 붙이지 않는다. 그게 맞다 — 부르는
    // 시점의 액세스 토큰은 이미 만료돼 있어서, 붙이면 재발급 자체가 401 이다.
    final response = await _guard(
      () => _dio.post<dynamic>(
        '$basePath/reissue',
        data: {'refreshToken': refreshToken},
        options: _deviceOptions,
      ),
    );
    return ReissuedAccessToken.fromJson(_body(response));
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면(프록시가 HTML 을 준 경우 등) 화면용
  /// 예외로 바꿔서, 화면이 형 변환 오류 대신 안내 문구를 받게 한다.
  Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw ApiException(
      '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.',
      status: response.statusCode,
    );
  }
}
