import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/favorite/data/http_favorite_api.dart';

import '../../core/network/fake_http_adapter.dart';

/// 찜 API(v1) 에 맞는 요청이 나가고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpFavoriteApi api;

  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpFavoriteApi(dio: dio);
  }

  /// 찜 목록 응답 한 건. 실제 `ConcertSummaryResponseDto` 모양이다.
  Map<String, dynamic> concertJson({
    int id = 7,
    String title = '김필 단독 콘서트',
    String status = 'ON_SALE',
  }) => {
    'id': id,
    'title': title,
    'genre': 'CONCERT',
    'posterImageUrl': 'poster/poster_main_kim_feel.gif',
    'ageRating': 'AGE_7',
    'status': status,
    'viewCount': 1203,
    'startDate': '2026-10-10T19:00:00',
    'endDate': '2026-10-12T21:00:00',
    'openAt': '2026-09-01T20:00:00',
    'venueId': 1,
    'venueName': '고척돔',
  };

  /// 목록 응답은 Spring 의 `PagedModel` 이라 배열이 `content` 안에 있다.
  Map<String, dynamic> pagedJson(List<Map<String, dynamic>> content) => {
    'content': content,
    'page': {
      'size': 100,
      'number': 0,
      'totalElements': content.length,
      'totalPages': 1,
    },
  };

  group('내 찜 목록', () {
    test('한 페이지만, 서버 최대치만큼 묻는다', () async {
      givenServer((_) => jsonResponse(pagedJson([concertJson()])));

      await api.fetchShows();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/wishes/me');
      expect(request.query['size'], '100');
    });

    test('카드에 필요한 값을 꺼내고, 온 순서를 지킨다', () async {
      givenServer(
        (_) => jsonResponse(
          pagedJson([
            concertJson(),
            concertJson(id: 9, title: '2026 아이유 콘서트', status: 'CLOSED'),
          ]),
        ),
      );

      final shows = await api.fetchShows();

      expect(shows.map((show) => show.id), [7, 9]);
      final first = shows.first;
      expect(first.title, '김필 단독 콘서트');
      expect(first.venueName, '고척돔');
      // 포스터는 저장소 key 그대로 둔다. 절대 주소로 바꾸는 일은 그리는 쪽이 한다.
      expect(first.posterImageUrl, 'poster/poster_main_kim_feel.gif');
      expect(first.startAt, DateTime(2026, 10, 10, 19));
    });

    test('아직 살 수 있는 공연만 판매 중이다', () async {
      givenServer(
        (_) => jsonResponse(
          pagedJson([
            concertJson(id: 1, status: 'SCHEDULED'),
            concertJson(id: 2, status: 'ON_SALE'),
            concertJson(id: 3, status: 'SOLD_OUT'),
            concertJson(id: 4, status: 'CLOSED'),
            concertJson(id: 5, status: 'CANCELED'),
          ]),
        ),
      );

      final onSale = {
        for (final show in await api.fetchShows()) show.id: show.isOnSale,
      };

      expect(onSale, {1: true, 2: true, 3: false, 4: false, 5: false});
    });

    test('공연 시작일이 없으면 비워 둔다', () async {
      final json = concertJson()..remove('startDate');
      givenServer((_) => jsonResponse(pagedJson([json])));

      expect((await api.fetchShows()).single.startAt, isNull);
    });

    test('우리가 아는 모양이 아니면 화면용 예외로 바꾼다', () async {
      // 프록시가 HTML 을 대신 준 경우다.
      givenServer((_) => ResponseBody.fromString('<html></html>', 200));

      expect(api.fetchShows(), throwsA(isA<ApiException>()));
    });

    test('로그인이 풀렸으면 서버 문구를 그대로 전한다', () async {
      givenServer(
        (_) => problemResponse(
          status: 401,
          errorMessage: '로그인이 필요합니다.',
          exception: 'AuthenticationException',
          errorCode: 'TOKEN_EXPIRED',
        ),
      );

      await expectLater(
        api.fetchShows(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 401)
              .having((e) => e.message, 'message', '로그인이 필요합니다.'),
        ),
      );
    });
  });

  group('찜·해제', () {
    test('공연 번호를 주소에 실어 PUT 한다', () async {
      givenServer((_) => emptyResponse());

      await api.addShow(7);

      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.path, '/api/v1/wishes/7');
      // 서버가 회원을 토큰에서 읽으므로 보낼 본문이 없다.
      expect(request.rawBody, isNull);
    });

    test('해제는 같은 주소로 DELETE 한다', () async {
      givenServer((_) => emptyResponse());

      await api.removeShow(7);

      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/api/v1/wishes/7');
    });

    test('없는 공연을 찜하면 서버 문구를 그대로 전한다', () async {
      givenServer(
        (_) => problemResponse(
          status: 404,
          errorMessage: '존재하지 않는 공연입니다.',
          exception: 'ConcertNotFoundException',
        ),
      );

      await expectLater(
        api.addShow(999),
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
