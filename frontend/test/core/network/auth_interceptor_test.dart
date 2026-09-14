import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/auth_interceptor.dart';

import 'fake_http_adapter.dart';

/// 토큰 자동 첨부 인터셉터. 가짜 서버로 요청에 무엇이 붙어 나갔는지 본다.
void main() {
  late FakeHttpAdapter adapter;
  late int unauthorizedCalls;

  /// [token] 을 돌려주는 세션이 꽂힌 dio. 응답은 [respond] 가 정한다.
  ///
  /// 회원 번호 헤더는 기본으로 끈다. 기본값(`kDebugMode`)은 테스트에서도 참이라,
  /// 켜고 끄는 동작을 따로 보려면 명시해야 한다.
  Dio build(
    String? token,
    ResponseBody Function(RecordedRequest) respond, {
    int? memberId,
    bool sendMemberIdHeader = false,
  }) {
    adapter = FakeHttpAdapter(respond);
    unauthorizedCalls = 0;
    return Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          accessToken: () => token,
          memberId: () => memberId,
          sendMemberIdHeader: sendMemberIdHeader,
          onUnauthorized: () => unauthorizedCalls++,
        ),
      );
  }

  ResponseBody ok(RecordedRequest _) => jsonResponse({'ok': true});

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
    final dio = build('access-jwt', ok, memberId: 7, sendMemberIdHeader: true);

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
    final dio = build('access-jwt', ok);

    await dio.post<dynamic>('/api/v1/auth/login', data: {'username': 'a'});
    await dio.get<dynamic>(
      '/api/v1/auth/availability',
      queryParameters: {'username': 'a'},
    );

    for (final request in adapter.requests) {
      expect(
        request.headers.containsKey(AuthInterceptor.authorizationHeader),
        isFalse,
        reason: '${request.path} 에 토큰이 붙었다',
      );
    }
  });

  test('401 이 오면 알리고, 다른 오류(400)에는 알리지 않는다', () async {
    final unauthorized = build(
      'stale-jwt',
      (_) => problemResponse(
        status: 401,
        errorMessage: '인증이 만료되었습니다.',
        exception: 'TokenExpiredException',
      ),
    );
    await expectLater(
      unauthorized.get<dynamic>('/api/v1/concerts'),
      throwsA(isA<DioException>()),
    );
    expect(unauthorizedCalls, 1);

    final badRequest = build(
      'access-jwt',
      (_) => problemResponse(
        status: 400,
        errorMessage: '입력값이 올바르지 않습니다.',
        exception: 'MethodArgumentNotValidException',
      ),
    );
    await expectLater(
      badRequest.get<dynamic>('/api/v1/concerts'),
      throwsA(isA<DioException>()),
    );
    expect(unauthorizedCalls, 0);
  });
}
