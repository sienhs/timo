import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/network/api_exception.dart';
import 'package:timo_gate/features/auth/constants.dart';
import 'package:timo_gate/features/auth/data/http_auth_api.dart';

import '../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
///
/// 주소·본문 키·헤더 이름은 백엔드 AuthController 와 DTO 에서 그대로 가져왔다.
/// 팬 앱의 같은 테스트에서 로그인·로그아웃·재발급만 남겼다.
void main() {
  const deviceId = 'test-device-id';
  const basePath = HttpAuthApi.basePath;

  late FakeHttpAdapter adapter;

  HttpAuthApi build(FutureOr<ResponseBody> Function(RecordedRequest) respond) {
    adapter = FakeHttpAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    return HttpAuthApi(dio: dio, deviceId: deviceId);
  }

  /// 서버에 닿지 못한 상황. 어댑터가 dio 식 연결 오류를 던진다.
  Never connectionLost(RecordedRequest request) => throw DioException(
    type: DioExceptionType.connectionError,
    requestOptions: request.options,
  );

  group('로그인', () {
    test('아이디·비밀번호와 기기 식별자 헤더를 POST /login 으로 보내고 토큰을 읽는다', () async {
      final api = build(
        (_) => jsonResponse({
          'memberId': 7,
          'accessToken': 'access-jwt',
          'refreshToken': 'refresh-random',
          'accessTokenExpiresIn': 1800,
        }),
      );

      final tokens = await api.login(username: 'admin', password: 'abcd1234!');

      expect(tokens, isNotNull);
      expect(tokens!.memberId, 7);
      expect(tokens.accessToken, 'access-jwt');
      expect(tokens.refreshToken, 'refresh-random');
      expect(tokens.accessTokenExpiresIn, const Duration(seconds: 1800));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '$basePath/login');
      expect(request.headers[HttpAuthApi.deviceIdHeader], deviceId);
      expect(request.jsonBody, {'username': 'admin', 'password': 'abcd1234!'});
    });

    test('아이디·비밀번호가 틀리면(400 LoginFailed) 예외가 아니라 null 이다', () async {
      final api = build(
        (_) => problemResponse(
          status: 400,
          errorMessage: '아이디 또는 비밀번호가 올바르지 않습니다.',
          exception: AuthServerErrors.loginFailed,
        ),
      );

      expect(await api.login(username: 'admin', password: 'wrong'), isNull);
    });

    test('정지된 계정(403)은 서버 문구를 담은 예외로 던진다', () async {
      final api = build(
        (_) => problemResponse(
          status: 403,
          errorMessage: '정지된 계정입니다. 고객센터로 문의해 주세요.',
          exception: 'MemberSuspendedException',
        ),
      );

      await expectLater(
        api.login(username: 'admin', password: 'abcd1234!'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message', contains('정지된 계정'))
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                'MemberSuspendedException',
              ),
        ),
      );
    });

    test('서버에 닿지 못하면 안내 문구를 담은 예외가 나간다', () async {
      final api = build(connectionLost);

      await expectLater(
        api.login(username: 'admin', password: 'abcd1234!'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.message, 'message', '인터넷 연결을 확인해주세요.'),
        ),
      );
    });

    test('JSON 이 아닌 응답(프록시 HTML 등)은 화면용 예외로 바꾼다', () async {
      final api = build(
        (_) => ResponseBody.fromString(
          '<html>Service Unavailable</html>',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );

      await expectLater(
        api.login(username: 'admin', password: 'abcd1234!'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('로그아웃', () {
    test(
      '리프레시 토큰과 기기 식별자 헤더를 POST /logout 으로 보내고, 본문 없는 204 를 그대로 받는다',
      () async {
        final api = build((_) => ResponseBody.fromString('', 204));

        await expectLater(api.logout('refresh-random'), completes);

        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '$basePath/logout');
        expect(request.headers[HttpAuthApi.deviceIdHeader], deviceId);
        expect(request.jsonBody, {'refreshToken': 'refresh-random'});
      },
    );

    test('서버에 닿지 못하면 예외로 알린다. 무시할지는 부르는 쪽이 정한다', () async {
      final api = build(connectionLost);

      await expectLater(
        api.logout('refresh-random'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('토큰 재발급', () {
    test('리프레시 토큰과 기기 식별자 헤더를 POST /reissue 로 보내고 새 토큰을 읽는다', () async {
      final api = build(
        (_) => jsonResponse({
          'accessToken': 'new-access-jwt',
          'accessTokenExpiresIn': 1800,
        }),
      );

      final reissued = await api.reissue('refresh-random');

      expect(reissued.accessToken, 'new-access-jwt');
      expect(reissued.expiresIn, const Duration(seconds: 1800));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '$basePath/reissue');
      expect(request.headers[HttpAuthApi.deviceIdHeader], deviceId);
      expect(request.jsonBody, {'refreshToken': 'refresh-random'});
    });

    test('서버가 거절하면(401 TOKEN_INVALID) 이유 코드를 담은 예외로 던진다', () async {
      // 인터셉터가 이 코드를 보고 "재발급은 끝났다, 로그아웃" 을 판단한다.
      final api = build(
        (_) => problemResponse(
          status: 401,
          errorCode: AuthErrorCodes.tokenInvalid,
          errorMessage: '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
          exception: 'TokenInvalidException',
        ),
      );

      await expectLater(
        api.reissue('never-issued'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 401)
              .having(
                (e) => e.errorCode,
                'errorCode',
                AuthErrorCodes.tokenInvalid,
              ),
        ),
      );
    });
  });
}
