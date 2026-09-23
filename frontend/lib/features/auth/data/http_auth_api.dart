import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/signup_draft.dart';
import '../models/auth_tokens.dart';
import '../models/reissued_access_token.dart';
import 'auth_api.dart';
import 'device_id.dart';

/// 백엔드 인증 API(`/api/v1/auth`)에 실제로 요청하는 [AuthApi]. dio 가 던지는
/// 예외는 전부 [ApiException] 으로 바꿔 던진다. [dio] 와 [deviceId] 는 테스트를
/// 위해 받고, 앱에서는 [ApiClient.dio] 와 [DeviceId.value] 를 쓴다.
class HttpAuthApi implements AuthApi {
  HttpAuthApi({Dio? dio, String? deviceId})
    : _dio = dio ?? ApiClient.dio,
      _deviceId = deviceId ?? DeviceId.value;

  static const basePath = '/api/v1/auth';

  /// 가입 요청에 붙이는 기기 식별자 헤더. 백엔드 AuthController 와 이름이 같다.
  static const deviceIdHeader = 'X-Device-Id';

  final Dio _dio;
  final String _deviceId;

  @override
  Future<Duration> requestVerificationCode(String phoneNumber) async {
    final response = await _guard(
      () => _dio.post<dynamic>(
        '$basePath/sms/send',
        data: {'phoneNumber': phoneNumber},
      ),
    );
    return Duration(
      seconds: (_body(response)['expiresInSeconds'] as num).toInt(),
    );
  }

  @override
  Future<String?> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      final response = await _guard(
        () => _dio.post<dynamic>(
          '$basePath/sms/verify',
          data: {'phoneNumber': phoneNumber, 'code': code},
        ),
      );
      return _body(response)['verificationTicket'] as String;
    } on ApiException catch (e) {
      // 번호가 틀린 것은 정상 흐름에서 예상되는 결과라 값(null)으로 돌려준다.
      // 만료·시도 횟수 초과는 화면이 다르게 안내해야 하므로 예외로 둔다.
      if (e.exceptionName == AuthServerErrors.smsCodeMismatch) return null;
      rethrow;
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) =>
      _checkAvailability({'username': username});

  @override
  Future<bool> isNicknameAvailable(String nickname) =>
      _checkAvailability({'nickname': nickname});

  /// 아이디·닉네임 중복 확인은 주소가 하나고, 쿼리 파라미터 이름으로 무엇을
  /// 확인할지 가른다. 둘 중 하나만 보내야 한다.
  Future<bool> _checkAvailability(Map<String, String> query) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$basePath/availability', queryParameters: query),
    );
    return _body(response)['available'] as bool;
  }

  @override
  Future<AuthTokens> signUp(SignupDraft draft) async {
    final response = await _guard(
      () => _dio.post<dynamic>(
        '$basePath/signup',
        data: {
          'verificationTicket': draft.verificationTicket,
          'phoneNumber': draft.phoneNumber,
          'name': draft.name,
          'username': draft.username,
          'password': draft.password,
          'nickname': draft.nickname,
        },
        options: Options(headers: {deviceIdHeader: _deviceId}),
      ),
    );
    return AuthTokens.fromJson(_body(response));
  }

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
          // 가입 때와 같은 기기 식별자를 보내야 서버가 같은 기기의 세션을 갱신한다.
          options: Options(headers: {deviceIdHeader: _deviceId}),
        ),
      );
      return AuthTokens.fromJson(_body(response));
    } on ApiException catch (e) {
      // 아이디 없음·비밀번호 틀림은 서버가 하나로 묶어 400 으로 주고 여기선 null.
      // 정지·탈퇴 계정(403)과 네트워크 실패는 안내가 달라 예외로 둔다.
      if (e.exceptionName == AuthServerErrors.loginFailed) return null;
      rethrow;
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    // 응답은 204 로 본문이 없어 읽지 않는다. 서버는 토큰이 틀려도 204 라 여기서
    // 나는 예외는 네트워크가 끊긴 경우뿐이다.
    await _guard(
      () => _dio.post<dynamic>(
        '$basePath/logout',
        data: {'refreshToken': refreshToken},
        // 서버가 (회원, 기기) 한 쌍으로 세션을 두므로 어느 기기인지 같이 보낸다.
        options: Options(headers: {deviceIdHeader: _deviceId}),
      ),
    );
  }

  @override
  Future<ReissuedAccessToken> reissue(String refreshToken) async {
    // 인증 주소라 인터셉터가 액세스 토큰을 붙이지 않는다. 부르는 시점의 액세스
    // 토큰은 이미 만료돼 있어 붙이면 재발급 요청 자체가 401 로 막힌다.
    final response = await _guard(
      () => _dio.post<dynamic>(
        '$basePath/reissue',
        data: {'refreshToken': refreshToken},
        // 서버가 토큰이 발급된 기기와 같은지 대조한다. 다르면 401 이다.
        options: Options(headers: {deviceIdHeader: _deviceId}),
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
