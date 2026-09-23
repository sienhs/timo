import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/http_auth_api.dart';
import 'package:timo/features/auth/models/signup_draft.dart';

import '../../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
/// 주소·본문 키·헤더 이름은 백엔드 AuthController 와 DTO 에서 그대로 가져왔다.
void main() {
  const deviceId = 'test-device-id';
  const basePath = HttpAuthApi.basePath;

  late FakeHttpAdapter adapter;

  /// 다음 요청에 [respond] 로 응답하는 구현을 만든다.
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

  group('인증번호 받기', () {
    test('숫자만 담아 POST /sms/send 로 보내고 유효 시간을 돌려준다', () async {
      final api = build((_) => jsonResponse({'expiresInSeconds': 180}));

      final validFor = await api.requestVerificationCode('01012345678');

      expect(validFor, const Duration(seconds: 180));
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '$basePath/sms/send');
      expect(request.jsonBody, {'phoneNumber': '01012345678'});
    });

    test('발송 횟수 초과(429)는 서버 문구를 담은 예외로 던진다', () async {
      final api = build(
        (_) => problemResponse(
          status: 429,
          errorMessage: '인증 문자 발송 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요.',
          exception: 'SmsSendLimitExceededException',
        ),
      );

      await expectLater(
        api.requestVerificationCode('01012345678'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 429)
              .having((e) => e.message, 'message', contains('발송 횟수'))
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                'SmsSendLimitExceededException',
              ),
        ),
      );
    });

    test('이미 가입된 번호(409)도 서버 문구를 담은 예외로 던진다', () async {
      final api = build(
        (_) => problemResponse(
          status: 409,
          errorMessage: '이미 가입된 전화번호입니다.',
          exception: 'PhoneNumberDuplicatedException',
        ),
      );

      await expectLater(
        api.requestVerificationCode('01012345678'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', '이미 가입된 전화번호입니다.')
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                AuthServerErrors.phoneNumberDuplicated,
              ),
        ),
      );
    });
  });

  group('인증하기', () {
    test('맞으면 서버가 준 티켓을 돌려준다', () async {
      final api = build(
        (_) => jsonResponse({
          'verificationTicket': 'ticket-abc',
          'expiresInSeconds': 1800,
        }),
      );

      final ticket = await api.verifyCode(
        phoneNumber: '01012345678',
        code: '123456',
      );

      expect(ticket, 'ticket-abc');
      final request = adapter.requests.single;
      expect(request.path, '$basePath/sms/verify');
      expect(request.jsonBody, {
        'phoneNumber': '01012345678',
        'code': '123456',
      });
    });

    test('틀리면(400 SmsCodeMismatch) 예외가 아니라 null 이다', () async {
      final api = build(
        (_) => problemResponse(
          status: 400,
          errorMessage: '인증 코드가 올바르지 않습니다.',
          exception: AuthServerErrors.smsCodeMismatch,
        ),
      );

      final ticket = await api.verifyCode(
        phoneNumber: '01012345678',
        code: '000000',
      );

      expect(ticket, isNull);
    });

    test('만료(400 SmsCodeNotFound)는 틀린 것과 달리 예외로 던진다', () async {
      final api = build(
        (_) => problemResponse(
          status: 400,
          errorMessage: '인증 코드가 만료되었습니다. 다시 요청해 주세요.',
          exception: 'SmsCodeNotFoundException',
        ),
      );

      await expectLater(
        api.verifyCode(phoneNumber: '01012345678', code: '123456'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.message, 'message', contains('만료'))
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                'SmsCodeNotFoundException',
              ),
        ),
      );
    });
  });

  group('중복 확인', () {
    test('아이디는 GET /availability?username= 으로 묻고 available 을 읽는다', () async {
      final api = build((_) => jsonResponse({'available': false}));

      final available = await api.isUsernameAvailable('timo');

      expect(available, isFalse);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '$basePath/availability');
      expect(request.query, {'username': 'timo'});
      expect(request.rawBody, isNull);
    });

    test('닉네임은 nickname 파라미터 하나만 보내고, 한글이 그대로 간다', () async {
      final api = build((_) => jsonResponse({'available': true}));

      final available = await api.isNicknameAvailable('티모2');

      expect(available, isTrue);
      expect(adapter.requests.single.query, {'nickname': '티모2'});
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
        api.isUsernameAvailable('timo'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('가입', () {
    const draft = SignupDraft(
      phoneNumber: '01012345678',
      verificationTicket: 'ticket-abc',
      name: '홍길동',
      username: 'minsuk_01',
      password: 'abcd1234!',
      nickname: '티모2',
    );

    test('여섯 값과 기기 식별자 헤더를 POST /signup 으로 보내고 결과를 읽는다', () async {
      final api = build(
        (_) => jsonResponse({
          'memberId': 7,
          'accessToken': 'access-jwt',
          'refreshToken': 'refresh-random',
          'accessTokenExpiresIn': 1800,
        }, status: 201),
      );

      final result = await api.signUp(draft);

      expect(result.memberId, 7);
      expect(result.accessToken, 'access-jwt');
      expect(result.refreshToken, 'refresh-random');
      expect(result.accessTokenExpiresIn, const Duration(seconds: 1800));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '$basePath/signup');
      expect(request.headers[HttpAuthApi.deviceIdHeader], deviceId);
      expect(request.jsonBody, {
        'verificationTicket': 'ticket-abc',
        'phoneNumber': '01012345678',
        'name': '홍길동',
        'username': 'minsuk_01',
        'password': 'abcd1234!',
        'nickname': '티모2',
      });
    });

    test('닉네임 중복(409)은 이름까지 담은 예외로 던져 화면이 가를 수 있다', () async {
      final api = build(
        (_) => problemResponse(
          status: 409,
          errorMessage: '이미 사용 중인 닉네임입니다.',
          exception: AuthServerErrors.nicknameDuplicated,
        ),
      );

      await expectLater(
        api.signUp(draft),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', '이미 사용 중인 닉네임입니다.')
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                AuthServerErrors.nicknameDuplicated,
              ),
        ),
      );
    });

    test('서버에 닿지 못하면 dio 예외가 아니라 안내 문구를 담은 예외가 나간다', () async {
      final api = build(connectionLost);

      await expectLater(
        api.signUp(draft),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.message, 'message', '인터넷 연결을 확인해주세요.'),
        ),
      );
    });
  });

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

      final tokens = await api.login(
        username: 'timo_test1',
        password: 'abcd1234!',
      );

      expect(tokens, isNotNull);
      expect(tokens!.memberId, 7);
      expect(tokens.accessToken, 'access-jwt');
      expect(tokens.refreshToken, 'refresh-random');
      expect(tokens.accessTokenExpiresIn, const Duration(seconds: 1800));

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '$basePath/login');
      expect(request.headers[HttpAuthApi.deviceIdHeader], deviceId);
      expect(request.jsonBody, {
        'username': 'timo_test1',
        'password': 'abcd1234!',
      });
    });

    test('아이디·비밀번호가 틀리면(400 LoginFailed) 예외가 아니라 null 이다', () async {
      final api = build(
        (_) => problemResponse(
          status: 400,
          errorMessage: '아이디 또는 비밀번호가 올바르지 않습니다.',
          exception: AuthServerErrors.loginFailed,
        ),
      );

      final tokens = await api.login(username: 'timo_test1', password: 'wrong');

      expect(tokens, isNull);
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
        api.login(username: 'timo_test1', password: 'abcd1234!'),
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
        api.login(username: 'timo_test1', password: 'abcd1234!'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '인터넷 연결을 확인해주세요.',
          ),
        ),
      );
    });
  });

  group('로그아웃', () {
    test(
      '리프레시 토큰과 기기 식별자 헤더를 POST /logout 으로 보내고, 본문 없는 204 를 그대로 받는다',
      () async {
        // 서버는 본문 없이 204 만 준다. 다른 응답처럼 JSON 으로 읽으려 들면 깨진다.
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
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', isNull)
              .having((e) => e.message, 'message', '인터넷 연결을 확인해주세요.'),
        ),
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

    test('응답에 리프레시 토큰이 없다. 회전시키지 않으므로 갖고 있던 걸 계속 쓴다', () async {
      final api = build(
        (_) => jsonResponse({
          'accessToken': 'new-access-jwt',
          'accessTokenExpiresIn': 1800,
        }),
      );

      // 모델에 담을 자리 자체가 없다는 것을 형으로 못 박아 둔다. 서버가 나중에
      // 회전을 시작하면 이 테스트가 아니라 모델부터 바꿔야 한다.
      final reissued = await api.reissue('refresh-random');

      expect(reissued.toString(), isNot(contains('refresh')));
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

    test('서버에 닿지 못하면 안내 문구를 담은 예외가 나간다', () async {
      final api = build(connectionLost);

      await expectLater(
        api.reissue('refresh-random'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '인터넷 연결을 확인해주세요.',
          ),
        ),
      );
    });
  });
}
