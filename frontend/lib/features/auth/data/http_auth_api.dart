import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/signup_draft.dart';
import '../models/signup_result.dart';
import 'auth_api.dart';
import 'device_id.dart';

/// 백엔드 인증 API(`/api/v1/auth`)에 실제로 요청하는 [AuthApi].
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다. dio 가 던지는 예외는 전부 [ApiException] 으로 바꿔
/// 던지므로 화면은 dio 를 모른다.
///
/// [dio] 와 [deviceId] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아
/// [ApiClient.dio] 와 [DeviceId.value] 를 쓰고, 테스트에서는 가짜 어댑터를 꽂은
/// dio 와 고정된 식별자를 넣어 요청·응답을 서버 없이 검사한다.
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
  Future<SignupResult> signUp(SignupDraft draft) async {
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
    return SignupResult.fromJson(_body(response));
  }

  /// 로그인 API 는 백엔드에 아직 없다. 로그인 화면은 [MockAuthApi] 를 쓴다.
  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    throw UnsupportedError('로그인 API 는 아직 없다. 로그인 화면은 목을 쓴다.');
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
