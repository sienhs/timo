import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/auth_interceptor.dart';

import 'fake_http_adapter.dart';

/// 토큰 자동 첨부와 만료 시 재발급. 가짜 서버로 무엇이 나가고 무엇을 다시
/// 보내는지 본다.
///
/// 주소와 이유 코드는 백엔드 규약에서 그대로 가져왔다. 인증 주소는
/// `/api/v1/auth/…`, 만료는 `TOKEN_EXPIRED`, 못 쓰는 토큰은 `TOKEN_INVALID` 다.
void main() {
  late FakeHttpAdapter adapter;
  late int unauthorizedCalls;
  late int reissueCalls;

  /// 지금 액세스 토큰. 실제 앱에서 세션이 들고 있는 값을 변수 하나로 흉내 낸다.
  /// 재발급이 성공하면 이 값이 바뀌고, 다시 보낸 요청에 그게 붙어야 한다.
  late String? token;

  /// [token] 을 돌려주는 세션이 꽂힌 dio. 응답은 [respond] 가 정한다.
  ///
  /// 회원 번호 헤더는 기본으로 끈다. 기본값(`kDebugMode`)은 테스트에서도 참이라,
  /// 켜고 끄는 동작을 따로 보려면 명시해야 한다.
  ///
  /// [onReissue] 를 안 넘기면 재발급은 성공하고 토큰이 `fresh-jwt` 로 바뀐다.
  Dio build(
    String? initialToken,
    FutureOr<ResponseBody> Function(RecordedRequest) respond, {
    int? memberId,
    bool sendMemberIdHeader = false,
    Future<bool> Function()? onReissue,
  }) {
    adapter = FakeHttpAdapter(respond);
    unauthorizedCalls = 0;
    reissueCalls = 0;
    token = initialToken;

    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;

    return dio
      ..interceptors.add(
        AuthInterceptor(
          dio: dio,
          accessToken: () => token,
          memberId: () => memberId,
          sendMemberIdHeader: sendMemberIdHeader,
          onUnauthorized: () => unauthorizedCalls++,
          reissue: () async {
            reissueCalls++;
            if (onReissue != null) return onReissue();
            token = 'fresh-jwt';
            return true;
          },
        ),
      );
  }

  ResponseBody ok(RecordedRequest _) => jsonResponse({'ok': true});

  /// 만료된 토큰이라는 401. 재발급하면 풀리는 쪽이다.
  ResponseBody expired() => problemResponse(
    status: 401,
    errorCode: 'TOKEN_EXPIRED',
    errorMessage: '인증이 만료되었습니다.',
    exception: 'TokenExpiredException',
  );

  /// 못 쓰는 토큰이라는 401. 재발급해도 소용없는 쪽이다.
  ResponseBody invalid() => problemResponse(
    status: 401,
    errorCode: 'TOKEN_INVALID',
    errorMessage: '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
    exception: 'TokenInvalidException',
  );

  /// 첫 요청만 만료로 막고 그다음부터는 통과시키는 가짜 서버.
  FutureOr<ResponseBody> Function(RecordedRequest) expiresOnce() {
    var served = 0;
    return (request) => served++ == 0 ? expired() : ok(request);
  }

  group('토큰 첨부', () {
    test('로그인 상태면 Authorization 헤더에 Bearer 토큰이 붙는다', () async {
      final dio = build('access-jwt', ok);

      await dio.get<dynamic>('/api/v1/concerts');

      expect(
        adapter.requests.single.headers[AuthInterceptor.authorizationHeader],
        'Bearer access-jwt',
      );
    });

    test('로그인 상태가 아니면 헤더를 붙이지 않는다', () async {
      final dio = build(null, ok);

      await dio.get<dynamic>('/api/v1/concerts');

      expect(
        adapter.requests.single.headers.containsKey(
          AuthInterceptor.authorizationHeader,
        ),
        isFalse,
      );
    });

    test('회원 번호 헤더를 켜면 로그인 상태에서 토큰과 함께 X-Member-Id 가 붙는다', () async {
      final dio = build(
        'access-jwt',
        ok,
        memberId: 7,
        sendMemberIdHeader: true,
      );

      await dio.get<dynamic>('/api/v1/members/me');

      expect(
        adapter.requests.single.headers[AuthInterceptor.memberIdHeader],
        '7',
      );
    });

    test('회원 번호 헤더를 꺼 두면 로그인 상태라도 X-Member-Id 를 붙이지 않는다', () async {
      final dio = build('access-jwt', ok, memberId: 7);

      await dio.get<dynamic>('/api/v1/members/me');

      expect(
        adapter.requests.single.headers.containsKey(
          AuthInterceptor.memberIdHeader,
        ),
        isFalse,
      );
    });

    test('회원 번호 헤더를 켜도 로그아웃 상태·인증 주소에는 붙이지 않는다', () async {
      final loggedOut = build(null, ok, sendMemberIdHeader: true);
      await loggedOut.get<dynamic>('/api/v1/members/me');
      expect(
        adapter.requests.single.headers.containsKey(
          AuthInterceptor.memberIdHeader,
        ),
        isFalse,
      );

      final public = build(
        'access-jwt',
        ok,
        memberId: 7,
        sendMemberIdHeader: true,
      );
      await public.post<dynamic>('/api/v1/auth/login', data: {'username': 'a'});
      expect(
        adapter.requests.single.headers.containsKey(
          AuthInterceptor.memberIdHeader,
        ),
        isFalse,
      );
    });

    test('인증 주소(/api/v1/auth/…)에는 로그인 상태라도 붙이지 않는다', () async {
      // 만료된 토큰이 붙으면 로그인·재발급 자체가 401 로 막힌다.
      final dio = build('access-jwt', ok);

      await dio.post<dynamic>('/api/v1/auth/login', data: {'username': 'a'});
      await dio.get<dynamic>(
        '/api/v1/auth/availability',
        queryParameters: {'username': 'a'},
      );
      await dio.post<dynamic>('/api/v1/auth/reissue', data: {'r': 'x'});

      for (final request in adapter.requests) {
        expect(
          request.headers.containsKey(AuthInterceptor.authorizationHeader),
          isFalse,
          reason: '${request.path} 에 토큰이 붙었다',
        );
      }
    });
  });

  group('만료되면 재발급하고 원래 요청을 잇는다', () {
    test('새 토큰으로 다시 보내고, 화면은 성공만 받는다', () async {
      final dio = build('stale-jwt', expiresOnce());

      final response = await dio.get<dynamic>('/api/v1/members/me');

      // 화면은 만료가 있었는지 모른다.
      expect(response.statusCode, 200);
      expect(reissueCalls, 1);
      expect(unauthorizedCalls, 0);

      // 같은 주소로 두 번 나갔고, 두 번째에 새 토큰이 붙었다.
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.first.headers[AuthInterceptor.authorizationHeader],
        'Bearer stale-jwt',
      );
      expect(
        adapter.requests.last.headers[AuthInterceptor.authorizationHeader],
        'Bearer fresh-jwt',
      );
    });

    test('본문과 쿼리가 그대로 다시 나간다', () async {
      final dio = build('stale-jwt', expiresOnce());

      await dio.post<dynamic>(
        '/api/v1/seats/hold',
        data: {'seatId': 12},
        queryParameters: {'concertId': '3'},
      );

      final retried = adapter.requests.last;
      expect(retried.method, 'POST');
      expect(retried.path, '/api/v1/seats/hold');
      expect(retried.jsonBody, {'seatId': 12});
      expect(retried.query, {'concertId': '3'});
    });
  });

  group('재발급은 한 번만 나간다', () {
    test('동시에 만료된 요청이 셋이어도 재발급은 한 번이다', () async {
      // 이 묶음이 없으면 재발급이 셋 나가고, 늦게 온 응답이 먼저 받은 토큰을
      // 덮어써 상태가 뒤엉킨다.
      var served = 0;
      final dio = build(
        'stale-jwt',
        // 처음 세 요청(동시에 나간 것들)만 막고, 재시도는 통과시킨다.
        (request) => served++ < 3 ? expired() : ok(request),
        onReissue: () async {
          // 실제 재발급처럼 한 박자 쉬어야 동시성이 재현된다.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          token = 'fresh-jwt';
          return true;
        },
      );

      final responses = await Future.wait([
        dio.get<dynamic>('/api/v1/members/me'),
        dio.get<dynamic>('/api/v1/seats'),
        dio.get<dynamic>('/api/v1/sections'),
      ]);

      expect(responses.map((r) => r.statusCode), everyElement(200));
      expect(reissueCalls, 1);
      expect(unauthorizedCalls, 0);
      // 처음 셋 + 재시도 셋.
      expect(adapter.requests, hasLength(6));
    });

    test('앞선 재발급이 끝난 뒤 또 만료되면 다시 재발급한다', () async {
      // 묶음을 끝난 뒤에도 붙들고 있으면 두 번째 만료를 못 살린다.
      final dio = build('stale-jwt', expiresOnce());
      await dio.get<dynamic>('/api/v1/members/me');
      expect(reissueCalls, 1);

      adapter = FakeHttpAdapter(expiresOnce());
      dio.httpClientAdapter = adapter;
      await dio.get<dynamic>('/api/v1/members/me');

      expect(reissueCalls, 2);
      expect(unauthorizedCalls, 0);
    });
  });

  group('재발급해도 소용없는 401', () {
    test('이유가 TOKEN_INVALID 면 재발급하지 않고 바로 로그아웃한다', () async {
      // 이 분기가 없으면 위조된 토큰으로 재발급 → 새 토큰도 거절 → 또 재발급으로
      // 무한 루프가 된다.
      final dio = build('forged-jwt', (_) => invalid());

      await expectLater(
        dio.get<dynamic>('/api/v1/members/me'),
        throwsA(isA<DioException>()),
      );

      expect(reissueCalls, 0);
      expect(unauthorizedCalls, 1);
      expect(adapter.requests, hasLength(1));
    });

    test('재발급이 실패하면 로그아웃하고 원래 오류를 넘긴다', () async {
      final dio = build(
        'stale-jwt',
        (_) => expired(),
        onReissue: () async => false,
      );

      await expectLater(
        dio.get<dynamic>('/api/v1/members/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            401,
          ),
        ),
      );

      expect(reissueCalls, 1);
      expect(unauthorizedCalls, 1);
      // 재시도는 하지 않았다.
      expect(adapter.requests, hasLength(1));
    });

    test('다시 보낸 요청이 또 401 이면 재발급을 되풀이하지 않는다', () async {
      // 이유 코드가 없는 401 처럼 위 분기를 빠져나온 경우의 안전장치다.
      final dio = build(
        'stale-jwt',
        (_) => problemResponse(
          status: 401,
          errorMessage: '인증이 필요합니다.',
          exception: 'AuthenticationException',
        ),
      );

      await expectLater(
        dio.get<dynamic>('/api/v1/members/me'),
        throwsA(isA<DioException>()),
      );

      expect(reissueCalls, 1);
      expect(unauthorizedCalls, 1);
      // 원래 요청 + 재시도 한 번. 그 뒤로는 멈춘다.
      expect(adapter.requests, hasLength(2));
    });
  });

  group('건드리지 않는 것', () {
    test('인증 주소의 401 은 재발급도 로그아웃도 하지 않는다', () async {
      // 재발급 요청 자체가 거절당한 경우가 여기다. 그건 재발급 함수가 거짓을
      // 돌려주는 것으로 이미 처리되므로, 여기서 또 로그아웃시키면 두 번 일어난다.
      final dio = build('access-jwt', (_) => invalid());

      await expectLater(
        dio.post<dynamic>('/api/v1/auth/reissue', data: {'r': 'x'}),
        throwsA(isA<DioException>()),
      );

      expect(reissueCalls, 0);
      expect(unauthorizedCalls, 0);
    });

    test('401 이 아닌 오류에는 아무것도 하지 않는다', () async {
      final dio = build(
        'access-jwt',
        (_) => problemResponse(
          status: 400,
          errorMessage: '입력값이 올바르지 않습니다.',
          exception: 'MethodArgumentNotValidException',
        ),
      );

      await expectLater(
        dio.get<dynamic>('/api/v1/concerts'),
        throwsA(isA<DioException>()),
      );

      expect(reissueCalls, 0);
      expect(unauthorizedCalls, 0);
    });
  });
}
