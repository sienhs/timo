import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// dio 의 어댑터 자리에 꽂는 가짜 서버.
///
/// 실제 네트워크 대신 [handler] 가 요청을 받아 응답을 돌려주고, 들어온 요청은
/// [requests] 에 기록한다. API 구현 테스트는 이걸로 "맞는 주소·방식·본문·헤더로
/// 요청이 나갔는지" 와 "응답을 맞게 읽었는지" 를 서버 없이 검사한다.
///
/// http_mock_adapter 같은 패키지를 붙이지 않은 이유: 필요한 건 이 정도이고,
/// dio 의 어댑터 인터페이스가 메서드 둘뿐이라 직접 만드는 쪽이 의존성보다 싸다.
///
/// 쓰는 법:
/// ```dart
/// final adapter = FakeHttpAdapter((request) => jsonResponse({'ok': true}));
/// final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
///   ..httpClientAdapter = adapter;
/// ```
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  /// 요청을 받아 응답을 만든다. DioException 을 던지면 dio 가 그 실패 종류
  /// 그대로 처리한다(네트워크 끊김 흉내에 쓴다).
  final FutureOr<ResponseBody> Function(RecordedRequest request) handler;

  /// 도착한 순서대로 쌓인다.
  final requests = <RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // dio 는 본문을 JSON 문자열로 바꾼 뒤 바이트 스트림으로 넘긴다. 실제
    // 서버가 받는 그 바이트를 그대로 읽어야 "무엇이 나갔는지" 를 정확히 본다.
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final request = RecordedRequest(
      options,
      bytes.isEmpty ? null : utf8.decode(bytes),
    );
    requests.add(request);
    return await handler(request);
  }

  @override
  void close({bool force = false}) {}
}

/// 가짜 서버에 도착한 요청 하나.
class RecordedRequest {
  /// [headers] 는 **도착한 순간의 사본**이다. 참조를 들고 있으면 안 된다 —
  /// 토큰 재발급 뒤 재시도는 같은 [RequestOptions] 를 다시 쓰기 때문에, 그때
  /// 헤더가 새 토큰으로 덮어써지면서 **먼저 기록해 둔 요청의 헤더까지 같이
  /// 바뀐다.** 그러면 "처음엔 옛 토큰, 재시도엔 새 토큰" 을 검사할 수가 없다.
  RecordedRequest(this.options, this.rawBody)
    : headers = Map<String, dynamic>.of(options.headers);

  final RequestOptions options;

  /// 본문 원문. 본문 없는 요청(GET)이면 null.
  final String? rawBody;

  /// 이 요청이 나갈 때 붙어 있던 헤더.
  final Map<String, dynamic> headers;

  String get method => options.method;

  /// 서버 주소를 뺀 경로 (예: `/api/v1/auth/sms/send`).
  String get path => options.uri.path;

  Map<String, String> get query => options.uri.queryParameters;

  /// JSON 본문을 맵으로. 본문이 없으면 실패한다(그 요청엔 본문이 없어야 한다는
  /// 검사는 [rawBody] 로 한다).
  Map<String, dynamic> get jsonBody =>
      jsonDecode(rawBody!) as Map<String, dynamic>;
}

/// JSON 성공 응답.
ResponseBody jsonResponse(Object body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

/// 서버 실패 응답. 백엔드 GlobalExceptionHandler 가 만드는 ProblemDetail 모양을
/// 그대로 따른다. 실제 서버는 `application/problem+json` 으로 내려주므로 그
/// 타입으로도 dio 가 JSON 을 풀어 주는지 함께 검사된다.
///
/// [errorCode] 는 **인증 실패 응답에만** 붙는다(백엔드 AuthExceptionHandler).
/// 다른 도메인의 실패를 흉내 낼 때는 넘기지 않아야 실제 응답과 같아진다.
ResponseBody problemResponse({
  required int status,
  required String errorMessage,
  required String exception,
  String? errorCode,
  List<Map<String, String>>? errors,
}) => ResponseBody.fromString(
  jsonEncode({
    'type': 'about:blank',
    'title': 'Error',
    'status': status,
    'instance': '/api/v1/auth',
    'errorCode': ?errorCode,
    'errorMessage': errorMessage,
    'timestamp': '2026-09-09 09:06:26',
    'exception': exception,
    'errors': ?errors,
  }),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/problem+json'],
  },
);

/// 본문 없는 성공 응답(204). 등록 취소처럼 결과가 "됐다" 하나뿐인 요청이 받는다.
ResponseBody emptyResponse({int status = 204}) =>
    ResponseBody.fromString('', status);
