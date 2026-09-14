import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/http_home_api.dart';
import 'package:timo/features/home/data/mock_home_data.dart';

import '../../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
///
/// 주소·쿼리 이름·응답 키는 백엔드 `ConcertApi` · `ConcertListRequestDto` ·
/// `ConcertSummaryResponseDto` 에서 그대로 가져왔다. 백엔드가 바뀌면 이 테스트를
/// 같이 고쳐야 한다. 그게 이 테스트의 역할이다.
void main() {
  const basePath = HttpHomeApi.basePath;

  late FakeHttpAdapter adapter;

  HttpHomeApi build(FutureOr<ResponseBody> Function(RecordedRequest) respond) {
    adapter = FakeHttpAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    return HttpHomeApi(dio: dio);
  }

  /// 스텁 서버의 고정 공연 한 건(`StubFixtures.CONCERTS[1]`)과 같은 모양.
  Map<String, Object?> concert({
    int id = 2,
    String status = 'SCHEDULED',
    Object? poster = 'poster/poster_main_lee.gif',
    Object? startDate = '2026-11-21T18:00:00',
    Object? endDate = '2026-11-22T21:00:00',
    Object? openAt = '2026-10-15T20:00:00',
  }) => {
    'id': id,
    'title': '이승기 콘서트',
    'genre': 'CONCERT',
    'posterImageUrl': poster,
    'ageRating': 'ALL',
    'status': status,
    'viewCount': 512,
    'startDate': startDate,
    'endDate': endDate,
    'openAt': openAt,
    'venueId': 1,
    'venueName': '고척돔',
  };

  /// Spring `PagedModel` 응답 모양.
  Map<String, Object> paged(List<Map<String, Object?>> content) => {
    'content': content,
    'page': {
      'size': 10,
      'number': 0,
      'totalElements': content.length,
      'totalPages': 1,
    },
  };

  group('티켓 오픈 임박', () {
    test('콘서트 · 오픈 예정 · 오픈 빠른 순으로 목록을 요청한다', () async {
      final api = build((_) => jsonResponse(paged([concert()])));

      await api.fetchTicketOpenSoon();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, basePath);
      expect(request.query, {
        'genre': 'CONCERT',
        'status': 'SCHEDULED',
        'sort': 'OPEN_SOON',
        'size': '${HomeMetrics.showRowSize}',
      });
    });

    test('응답 한 건을 카드 요약으로 읽는다', () async {
      final api = build((_) => jsonResponse(paged([concert()])));

      final shows = await api.fetchTicketOpenSoon();

      final show = shows.single;
      expect(show.id, 2);
      expect(show.title, '이승기 콘서트');
      expect(show.venueName, '고척돔');
      expect(show.posterImageUrl, 'poster/poster_main_lee.gif');
      expect(show.startAt, DateTime(2026, 11, 21, 18));
      expect(show.endAt, DateTime(2026, 11, 22, 21));
      expect(show.ticketOpenAt, DateTime(2026, 10, 15, 20));
      expect(show.periodLabel, '2026.11.21 ~ 11.22');
    });
  });

  group('인기 공연', () {
    test('콘서트 · 조회수 순으로 목록을 요청한다', () async {
      final api = build((_) => jsonResponse(paged([])));

      final shows = await api.fetchPopular();

      expect(shows, isEmpty);
      expect(adapter.requests.single.query, {
        'genre': 'CONCERT',
        'sort': 'POPULAR',
        'size': '${HomeMetrics.showRowSize}',
      });
    });

    test('이미 오픈한 공연은 openAt 이 와도 오픈 일시를 비운다', () async {
      final api = build(
        (_) => jsonResponse(paged([concert(status: 'ON_SALE')])),
      );

      final shows = await api.fetchPopular();

      expect(shows.single.ticketOpenAt, isNull);
    });

    test('포스터·일정이 비어 있어도 읽는다', () async {
      final api = build(
        (_) => jsonResponse(
          paged([
            concert(poster: null, startDate: null, endDate: null, openAt: null),
          ]),
        ),
      );

      final show = (await api.fetchPopular()).single;

      expect(show.posterImageUrl, isNull);
      expect(show.startAt, isNull);
      expect(show.ticketOpenAt, isNull);
      expect(show.periodLabel, HomeStrings.periodUndecided);
    });
  });

  group('검색', () {
    test('검색어를 keyword 로 보낸다', () async {
      final api = build((_) => jsonResponse(paged([concert()])));

      await api.search('이승기');

      expect(adapter.requests.single.query, {
        'genre': 'CONCERT',
        'keyword': '이승기',
        'size': '${HomeMetrics.searchPageSize}',
      });
    });
  });

  group('인기 아티스트', () {
    test('API 가 없어 요청 없이 목업을 돌려준다', () async {
      final api = build((_) => throw StateError('요청이 나가면 안 된다'));

      final artists = await api.fetchPopularArtists();

      expect(artists, MockHomeData.artists);
      expect(adapter.requests, isEmpty);
    });
  });

  group('실패', () {
    test('서버 오류(500)는 서버 문구를 담은 예외로 던진다', () async {
      final api = build(
        (_) => problemResponse(
          status: 500,
          errorMessage: '서버 내부 오류가 발생했습니다.',
          exception: 'RuntimeException',
        ),
      );

      await expectLater(
        api.fetchPopular(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 500)
              .having((e) => e.message, 'message', '서버 내부 오류가 발생했습니다.'),
        ),
      );
    });

    test('서버에 닿지 못하면 연결 안내 예외로 던진다', () async {
      final api = build(
        (request) => throw DioException(
          type: DioExceptionType.connectionError,
          requestOptions: request.options,
        ),
      );

      await expectLater(
        api.fetchTicketOpenSoon(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '인터넷 연결을 확인해주세요.',
          ),
        ),
      );
    });

    test('페이지 모양이 아닌 응답은 읽을 수 없다는 예외로 던진다', () async {
      final api = build((_) => jsonResponse({'unexpected': true}));

      await expectLater(
        api.fetchPopular(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            HomeStrings.unreadableResponse,
          ),
        ),
      );
    });
  });
}
