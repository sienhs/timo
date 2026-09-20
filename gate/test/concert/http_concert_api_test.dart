import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/network/api_exception.dart';
import 'package:timo_gate/features/concert/constants.dart';
import 'package:timo_gate/features/concert/data/http_concert_api.dart';

import '../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 공연 목록 규약대로 요청하고 응답을 읽는지, 가짜
/// 서버로 검사한다. 주소·응답 모양은 백엔드 ConcertApi 와 PagedModel 에서
/// 그대로 가져왔다.
void main() {
  late FakeHttpAdapter adapter;

  HttpConcertApi build(
    FutureOr<ResponseBody> Function(RecordedRequest) respond,
  ) {
    adapter = FakeHttpAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    return HttpConcertApi(dio: dio);
  }

  Map<String, Object?> summary(int id) => {
    'id': id,
    'title': '공연 $id',
    'venueName': '공연장',
    'posterImageUrl': null,
    'startDate': '2026-11-04T18:00:00',
    'endDate': '2026-11-04T21:00:00',
  };

  test('GET /api/v1/concerts 에 size 만 붙여 보내고 content 를 읽는다', () async {
    final api = build(
      (_) => jsonResponse({
        'content': [summary(1), summary(2)],
        'page': {'size': 100, 'number': 0, 'totalElements': 2, 'totalPages': 1},
      }),
    );

    final concerts = await api.findAll();

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, HttpConcertApi.concertsPath);
    expect(request.options.uri.queryParameters, {
      'size': '${ConcertMetrics.pageSize}',
    });
    expect(concerts.map((c) => c.id).toList(), [1, 2]);
  });

  test('검색어는 앞뒤 공백을 잘라 keyword 로 보내고, 빈 검색어는 보내지 않는다', () async {
    final api = build((_) => jsonResponse({'content': <Object>[]}));

    await api.findAll(keyword: '  콘서트 ');
    await api.findAll(keyword: '   ');

    expect(adapter.requests[0].options.uri.queryParameters['keyword'], '콘서트');
    expect(
      adapter.requests[1].options.uri.queryParameters.containsKey('keyword'),
      isFalse,
    );
  });

  test('content 가 없는 응답(프록시 HTML 등)은 ApiException', () async {
    final api = build(
      (_) => ResponseBody.fromString(
        '<html>bad gateway</html>',
        200,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
        },
      ),
    );

    await expectLater(api.findAll(), throwsA(isA<ApiException>()));
  });

  test('서버 오류는 ApiException 으로 바뀐다', () async {
    final api = build(
      (_) => problemResponse(
        status: 500,
        errorMessage: '서버 오류',
        exception: 'RuntimeException',
      ),
    );

    await expectLater(
      api.findAll(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 500)),
    );
  });
}
