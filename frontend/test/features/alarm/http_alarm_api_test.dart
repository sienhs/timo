import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/alarm/data/http_alarm_api.dart';
import 'package:timo/features/alarm/models/alarm_status.dart';

import '../../core/network/fake_http_adapter.dart';

/// 알림 신청 API(v1) 에 맞는 요청이 나가고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpAlarmApi api;

  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpAlarmApi(dio: dio);
  }

  group('신청 상태', () {
    test('공연 번호를 주소에 실어 묻고, 종류별 값을 읽는다', () async {
      givenServer(
        (_) => jsonResponse({'concertOpen': true, 'marketListing': false}),
      );

      final status = await api.fetchStatus(7);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/alarms/7');
      expect(status, const AlarmStatus(concertOpen: true));
    });

    test('우리가 아는 모양이 아니면 화면용 예외로 바꾼다', () async {
      // 프록시가 HTML 을 대신 준 경우다.
      givenServer((_) => ResponseBody.fromString('<html></html>', 200));

      expect(api.fetchStatus(7), throwsA(isA<ApiException>()));
    });
  });

  group('신청·해제', () {
    test('종류를 서버 이름으로 주소에 실어 PUT 한다', () async {
      givenServer((_) => emptyResponse());

      await api.subscribe(7, AlarmType.concertOpen);
      await api.subscribe(7, AlarmType.marketListing);

      expect(adapter.requests.map((r) => r.method), ['PUT', 'PUT']);
      expect(adapter.requests.map((r) => r.path), [
        '/api/v1/alarms/7/CONCERT_OPEN',
        '/api/v1/alarms/7/MARKET_LISTING',
      ]);
      // 서버가 회원을 토큰에서 읽으므로 보낼 본문이 없다.
      expect(adapter.requests.first.rawBody, isNull);
    });

    test('해제는 같은 주소로 DELETE 한다', () async {
      givenServer((_) => emptyResponse());

      await api.unsubscribe(7, AlarmType.marketListing);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/alarms/7/MARKET_LISTING');
    });

    test('없는 공연이면 서버 문구를 그대로 전한다', () async {
      givenServer(
        (_) => problemResponse(
          status: 404,
          errorMessage: '존재하지 않는 공연입니다.',
          exception: 'ConcertNotFoundException',
        ),
      );

      await expectLater(
        api.subscribe(999, AlarmType.concertOpen),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '존재하지 않는 공연입니다.',
          ),
        ),
      );
    });
  });
}
