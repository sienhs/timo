import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/data/http_home_api.dart';
import 'package:timo/features/home/models/trending_keyword.dart';

import '../../core/network/fake_http_adapter.dart';

/// 실제 서버 구현이 백엔드 규약대로 요청하고 응답을 읽는지, 가짜 서버로 검사한다.
/// 주소·쿼리 이름·응답 키는 백엔드 `ConcertApi`·`ArtistApi` 와 그 DTO 에서
/// 그대로 가져왔다. 백엔드가 바뀌면 이 테스트를 같이 고쳐야 한다.
void main() {
  const concertsPath = HttpHomeApi.concertsPath;
  const artistsPath = HttpHomeApi.artistsPath;

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
      expect(request.path, concertsPath);
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

    test('하루짜리 공연은 날짜를 한 번만 적는다', () async {
      // 서버는 하루 공연에도 endDate 를 시작일과 같은 날로 채워 준다.
      final api = build(
        (_) => jsonResponse(
          paged([
            concert(
              startDate: '2026-11-21T18:00:00',
              endDate: '2026-11-21T21:00:00',
            ),
          ]),
        ),
      );

      final show = (await api.fetchPopular()).single;

      expect(show.periodLabel, '2026.11.21');
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

  /// 백엔드 `ArtistSummaryResponseDto` 모양. 사진 키가 `profileImageUrl` 다.
  Map<String, Object?> artist({
    int id = 1,
    String name = '아이유',
    Object? profileImageUrl = 'artist/iu.jpg',
  }) => {'id': id, 'name': name, 'profileImageUrl': profileImageUrl};

  group('검색', () {
    test('검색어를 keyword 로 공연 목록에 보낸다', () async {
      final api = build((_) => jsonResponse(paged([concert()])));

      await api.search('이승기');

      final request = adapter.requests.single;
      expect(request.path, concertsPath);
      expect(request.query, {
        'genre': 'CONCERT',
        'keyword': '이승기',
        'size': '${HomeMetrics.searchPageSize}',
      });
    });

    test('예매 상태를 그대로 읽어 오픈 예정·예매중만 걸러 낼 수 있다', () async {
      final api = build(
        (_) => jsonResponse(
          paged([
            concert(id: 1, status: 'SCHEDULED'),
            concert(id: 2, status: 'ON_SALE'),
            concert(id: 3, status: 'SOLD_OUT'),
            concert(id: 4, status: 'CLOSED'),
            concert(id: 5, status: 'CANCELED'),
          ]),
        ),
      );

      final shows = await api.search('이승기');

      expect(shows.map((s) => s.status), [
        'SCHEDULED',
        'ON_SALE',
        'SOLD_OUT',
        'CLOSED',
        'CANCELED',
      ]);
      expect(shows.where((s) => s.isOpenOrUpcoming).map((s) => s.id), [1, 2]);
    });
  });

  group('관련 아티스트', () {
    test('검색어를 keyword 로 아티스트 목록에 보낸다', () async {
      final api = build((_) => jsonResponse(paged([artist()])));

      await api.searchArtists('아이');

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, artistsPath);
      expect(request.query, {
        'keyword': '아이',
        'size': '${HomeMetrics.relatedArtistPageSize}',
      });
    });

    test('응답 한 건을 이름·사진으로 읽는다', () async {
      final api = build((_) => jsonResponse(paged([artist()])));

      final artists = await api.searchArtists('아이');

      final found = artists.single;
      expect(found.name, '아이유');
      expect(found.profileImageUrl, 'artist/iu.jpg');
    });

    test('사진이 없어도 읽는다', () async {
      final api = build(
        (_) => jsonResponse(paged([artist(profileImageUrl: null)])),
      );

      final artists = await api.searchArtists('아이');

      expect(artists.single.profileImageUrl, isNull);
    });

    test('페이지 모양이 아닌 응답은 읽을 수 없다는 예외로 던진다', () async {
      final api = build((_) => jsonResponse({'unexpected': true}));

      await expectLater(
        api.searchArtists('아이'),
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

  group('인기 아티스트', () {
    test('최근 등록순으로 격자 크기만큼 아티스트 목록을 요청한다', () async {
      final api = build((_) => jsonResponse(paged([artist()])));

      final artists = await api.fetchPopularArtists();

      expect(artists.single.name, '아이유');
      final request = adapter.requests.single;
      expect(request.path, artistsPath);
      expect(request.query, {
        'sort': 'LATEST',
        'size': '${HomeMetrics.popularArtistGridSize}',
      });
    });
  });

  group('추천 검색어 아티스트', () {
    test('최근 등록순으로 한 줄만 아티스트 목록을 요청한다', () async {
      final api = build((_) => jsonResponse(paged([])));

      final artists = await api.fetchRecommendedArtists();

      expect(artists, isEmpty);
      final request = adapter.requests.single;
      expect(request.path, artistsPath);
      expect(request.query, {
        'sort': 'LATEST',
        'size': '${HomeMetrics.recommendedArtistRowSize}',
      });
    });
  });

  group('인기 검색어 (집계 API 없음)', () {
    /// 공연 둘 · 아티스트 둘을 주는 서버. 요청 경로로 가른다.
    ResponseBody respondByPath(RecordedRequest request) {
      if (request.path == concertsPath) {
        return jsonResponse(
          paged([
            {...concert(id: 1), 'title': '이승기 콘서트'},
            {...concert(id: 2), 'title': '로이킴 콘서트'},
          ]),
        );
      }
      return jsonResponse(
        paged([artist(id: 1, name: '이승기'), artist(id: 2, name: '로이킴')]),
      );
    }

    test('조회수 순 공연과 최근 등록순 아티스트를 함께 요청한다', () async {
      final api = build(respondByPath);

      await api.fetchTrendingKeywords();

      final byPath = {for (final r in adapter.requests) r.path: r.query};
      expect(byPath, hasLength(2));
      expect(byPath[concertsPath], {
        'genre': 'CONCERT',
        'sort': 'POPULAR',
        'size': '${HomeMetrics.trendingCount}',
      });
      expect(byPath[artistsPath], {
        'sort': 'LATEST',
        'size': '${HomeMetrics.trendingCount}',
      });
    });

    test('공연명을 앞에, 아티스트명을 뒤에 두고 1위부터 순위를 매긴다', () async {
      final now = DateTime(2026, 9, 4, 13, 20);
      adapter = FakeHttpAdapter(respondByPath);
      final api = HttpHomeApi(
        dio: Dio(BaseOptions(baseUrl: 'http://fake.test'))
          ..httpClientAdapter = adapter,
        clock: () => now,
      );

      final trending = await api.fetchTrendingKeywords();

      expect(trending.asOf, now);
      expect(trending.items.map((i) => i.rank), [1, 2, 3, 4]);
      expect(trending.items.map((i) => i.keyword), [
        '이승기 콘서트',
        '로이킴 콘서트',
        '이승기',
        '로이킴',
      ]);
    });

    test('첫 조회는 전부 보합이고, 다시 조회하면 직전 순위와 비교해 등락을 매긴다', () async {
      var swapped = false;
      final api = build((request) {
        if (request.path != concertsPath) return jsonResponse(paged([]));
        final titles = swapped
            ? ['로이킴 콘서트', '이승기 콘서트', '김필 콘서트']
            : ['이승기 콘서트', '로이킴 콘서트'];
        return jsonResponse(
          paged([
            for (final (i, title) in titles.indexed)
              {...concert(id: i + 1), 'title': title},
          ]),
        );
      });

      final first = await api.fetchTrendingKeywords();
      swapped = true;
      final second = await api.fetchTrendingKeywords();

      expect(
        first.items.map((i) => i.trend),
        everyElement(KeywordTrend.steady),
      );
      expect(second.items.map((i) => i.trend), [
        KeywordTrend.up, // 로이킴 2위 → 1위
        KeywordTrend.down, // 이승기 1위 → 2위
        KeywordTrend.steady, // 김필은 직전에 없었다
      ]);
    });

    test('같은 말은 먼저 온 자리만 남기고 열 개까지만 담는다', () async {
      final api = build(
        (request) => request.path == concertsPath
            ? jsonResponse(
                paged([
                  for (var i = 1; i <= 8; i++)
                    {...concert(id: i), 'title': '공연 $i'},
                ]),
              )
            : jsonResponse(
                paged([
                  artist(id: 1, name: '공연 1'),
                  artist(id: 2, name: '가수 A'),
                  artist(id: 3, name: '가수 B'),
                  artist(id: 4, name: '가수 C'),
                ]),
              ),
      );

      final trending = await api.fetchTrendingKeywords();

      expect(trending.items, hasLength(HomeMetrics.trendingCount));
      expect(trending.items.map((i) => i.keyword).toSet(), hasLength(10));
      expect(trending.items.last.keyword, '가수 B');
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
