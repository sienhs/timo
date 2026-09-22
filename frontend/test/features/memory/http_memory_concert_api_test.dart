import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/memory_concert_api.dart';
import 'package:timo/features/memory/models/concert_kit.dart';

import '../../core/network/fake_http_adapter.dart';

/// 소장품 카탈로그·소재 API 응답을 화면이 쓰는 모양으로 제대로 옮기는지.
void main() {
  late FakeHttpAdapter adapter;
  late HttpMemoryConcertApi api;

  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpMemoryConcertApi(dio: dio);
  }

  /// 서버 카탈로그 한 줄. 실제 `CollectibleConcertResponseDto` 모양이다.
  Map<String, dynamic> concertJson({
    int ticketId = 1024,
    String? artist = 'TIMO STAGE',
    String? date = '2026-09-26T19:30:00',
    int? goodsId,
  }) => {
    'ticketId': ticketId,
    'concertId': 3,
    'title': '빛으로 남은 밤',
    'artist': artist,
    'date': date,
    'venue': '서울 메모리 홀',
    'thumbnailUrl': 'poster/night.png',
    // 공연에 영상 컬럼이 없어 늘 null 이다.
    'videoUrl': null,
    'goodsId': goodsId,
  };

  group('getConcerts', () {
    test('한 줄이 티켓 한 장이고 날짜·시각·포스터·소장품 번호를 화면 모양으로 옮긴다', () async {
      givenServer(
        (_) => jsonResponse([
          concertJson(ticketId: 1024, goodsId: 7),
          concertJson(ticketId: 1025),
        ]),
      );

      final concerts = await api.getConcerts();

      expect(adapter.requests.single.path, '/api/v1/collectibles/concerts');
      expect(concerts, hasLength(2));

      final [made, fresh] = concerts;
      // 식별자는 문자열로 다룬다. 요청 경로에도 그대로 들어간다.
      expect(made.ticketId, '1024');
      expect(made.id, '3');
      expect(made.goodsId, '7');
      expect(fresh.goodsId, isNull);

      // LocalDateTime 한 값이 날짜와 시각으로 갈린다.
      expect(made.date, '2026.09.26');
      expect(made.time, '19:30');
      expect(made.ticketDetails['시간'], '19:30');
      // 저장소 key 는 앱이 읽을 절대 주소가 된다.
      expect(made.poster, endsWith('/poster/night.png'));
      expect(made.poster, startsWith('http'));
      // 영상은 없으니 데모 영상으로 채운다.
      expect(made.videoUrl, CatalogConstants.demoVideoAsset);
    });

    test('아티스트·날짜가 없어도 줄이 빠지지 않는다', () async {
      givenServer((_) => jsonResponse([concertJson(artist: null, date: null)]));

      final concert = (await api.getConcerts()).single;

      expect(concert.artist, '');
      expect(concert.date, '');
      expect(concert.time, isNull);
      // 시각이 없으면 뒷면에 시각 줄 자체가 없다.
      expect(concert.ticketDetails.keys, isNot(contains('시간')));
      // 좌석·예매 번호는 지어내지 않는다.
      expect(concert.ticketDetails.keys, isNot(contains('좌석')));
    });

    test('실패는 ApiException 으로 나간다', () {
      givenServer(
        (_) => problemResponse(
          status: 401,
          errorMessage: '인증이 필요합니다.',
          exception: 'AuthenticationException',
        ),
      );

      expect(api.getConcerts, throwsA(isA<ApiException>()));
    });
  });

  group('getKit', () {
    test('공연 아래 주소로 받고 배경·인물을 순서대로 옮긴다', () async {
      givenServer(
        (_) => jsonResponse({
          'concertId': 3,
          'backgrounds': [
            {
              'assetId': 1,
              'url': 'https://cdn.test/kit/bg1.jpg',
              'sortOrder': 0,
            },
            {'assetId': 2, 'url': 'kit/3/bg2.jpg', 'sortOrder': 1},
          ],
          'people': [],
        }),
      );

      final kit = await api.getKit('3');

      expect(adapter.requests.single.path, '/api/v1/concerts/3/kit');
      expect(kit.backgrounds.map((a) => a.source), [
        'https://cdn.test/kit/bg1.jpg',
        // key 로 온 것은 절대 주소가 된다.
        endsWith('/kit/3/bg2.jpg'),
      ]);
      expect(kit.backgrounds.every((a) => !a.isAsset), isTrue);
      expect(kit.people, isEmpty);

      // 비어 있는 쪽만 데모로 채운다.
      final filled = kit.orDemo();
      expect(filled.backgrounds, same(kit.backgrounds));
      expect(filled.people, ConcertKit.demo.people);
      expect(filled.people.every((a) => a.isAsset), isTrue);
    });

    test('티켓이 없는 공연은 403 이고 ApiException 이다', () {
      givenServer(
        (_) => problemResponse(
          status: 403,
          errorMessage: '이 공연의 티켓이 없습니다.',
          exception: 'ConcertKitForbiddenException',
        ),
      );

      expect(() => api.getKit('3'), throwsA(isA<ApiException>()));
    });
  });
}
