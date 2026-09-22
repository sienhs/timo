import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/show/data/http_show_api.dart';
import 'package:timo/features/show/models/show_detail.dart';

import '../../core/network/fake_http_adapter.dart';

/// 공연 상세 v1 API 에 맞는 요청이 나가고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpShowApi api;

  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpShowApi(dio: dio);
  }

  /// 공연 단건 응답. 실제 `ConcertDetailResponseDto` 모양이다.
  ///
  /// 가격(`sectionPrices`)이 이 안에 들어 있다. 예전에는 구역 목록을 따로
  /// 물어야 했다.
  Map<String, dynamic> concertJson({
    String status = 'ON_SALE',
    bool bookable = true,
    String? blockReason,
  }) => {
    'id': 7,
    'title': '김필 단독 콘서트',
    'genre': 'CONCERT',
    'posterImageUrl': 'poster/poster_main_kim_feel.gif',
    'imageUrls': ['detail/poster_detail_kim.jpg'],
    'description': '김필 단독 콘서트',
    'ageRating': 'AGE_7',
    'status': status,
    // 예매 가능 여부는 서버가 응답을 만들 때 계산해서 함께 준다. 상태만으로는
    // 알 수 없는 구간(마감 후 공연 종료 전 등)이 있어서다.
    'bookable': bookable,
    'blockReason': blockReason,
    'viewCount': 1203,
    'startDate': '2026-10-10T19:00:00',
    // 종료일이 시작일과 다르게 와도 화면은 하루만 쓴다.
    'endDate': '2026-10-12T21:00:00',
    'openAt': '2026-09-01T20:00:00',
    'venueId': 1,
    'venueName': '고척돔',
    'artists': [
      {'id': 1, 'name': '김필', 'profileImageUrl': 'artist/artist_kim_feel.jpg'},
    ],
    'sectionPrices': [
      {'sectionId': 1, 'sectionName': '1층 A블록', 'price': 150000},
      {'sectionId': 3, 'sectionName': '2층 C블록', 'price': 120000},
    ],
  };

  /// 공연을 제대로 돌려주는 서버.
  void givenWorkingServer({
    String status = 'ON_SALE',
    bool bookable = true,
    String? blockReason,
  }) {
    givenServer(
      (_) => jsonResponse(
        concertJson(
          status: status,
          bookable: bookable,
          blockReason: blockReason,
        ),
      ),
    );
  }

  group('요청', () {
    test('공연 번호를 주소에 실어 한 번만 묻는다', () async {
      givenWorkingServer();

      await api.fetchShowDetail(7);

      // 가격이 상세 응답에 있어 구역 목록을 따로 묻지 않는다.
      expect(adapter.requests, hasLength(1));
      final concert = adapter.requests.single;
      expect(concert.method, 'GET');
      expect(concert.path, '/api/v1/concerts/7');
    });

    test('구역 목록 주소는 부르지 않는다', () async {
      // 그 주소는 로그인해야 열린다. 부르지 않아야 로그인 전 사용자도 가격을 본다.
      givenWorkingServer();

      await api.fetchShowDetail(7);

      expect(
        adapter.requests.map((r) => r.path),
        isNot(contains('/api/v1/sections')),
      );
    });
  });

  group('응답 읽기', () {
    test('화면에 필요한 값을 꺼낸다', () async {
      givenWorkingServer();

      final detail = await api.fetchShowDetail(7);

      expect(detail.id, 7);
      expect(detail.title, '김필 단독 콘서트');
      expect(detail.venue, '고척돔');
      expect(detail.posterUrl, 'poster/poster_main_kim_feel.gif');
      expect(detail.startAt, DateTime(2026, 10, 10, 19));
      expect(detail.ticketOpenAt, DateTime(2026, 9, 1, 20));
      expect(detail.status, ShowStatus.onSale);
      expect(detail.artists.single.name, '김필');
      expect(detail.artists.single.photoUrl, 'artist/artist_kim_feel.jpg');
      expect(detail.imageUrls, ['detail/poster_detail_kim.jpg']);
    });

    test('상세 이미지 순서를 유지하고 필드가 없으면 빈 목록을 쓴다', () async {
      final json = concertJson()
        ..['imageUrls'] = ['detail/first.jpg', 'detail/second.jpg'];
      givenServer((_) => jsonResponse(json));
      expect((await api.fetchShowDetail(7)).imageUrls, [
        'detail/first.jpg',
        'detail/second.jpg',
      ]);

      json.remove('imageUrls');
      expect((await api.fetchShowDetail(7)).imageUrls, isEmpty);
    });

    test('가격을 상세 응답에서 구역 순서대로 읽는다', () async {
      givenWorkingServer();

      final prices = (await api.fetchShowDetail(7)).zonePrices;

      // 등급으로 묶지 않는다. 서버 등급이 하나뿐이라 묶으면 한 줄이 된다.
      expect(prices, hasLength(2));
      expect(prices.first.zoneName, '1층 A블록');
      expect(prices.first.price, 150000);
      expect(prices.last.zoneName, '2층 C블록');
    });

    test('가격이 비어 있어도 공연은 그린다', () async {
      // 구역이 아직 등록되지 않은 공연이면 빈 목록이 온다.
      final json = concertJson()..remove('sectionPrices');
      givenServer((_) => jsonResponse(json));

      final detail = await api.fetchShowDetail(7);

      expect(detail.title, '김필 단독 콘서트');
      expect(detail.zonePrices, isEmpty);
    });

    test('공연일은 하루만 쓰고, 시작 시각까지 적는다', () async {
      givenWorkingServer();

      final detail = await api.fetchShowDetail(7);

      // 서버는 종료일(10/12)도 주지만 단일 회차 공연이라 읽지 않는다.
      expect(detail.dateTimeLabel, '2026.10.10 (토) 19:00');
    });

    test('끝난 공연과 취소된 공연을 구분한다', () async {
      givenWorkingServer(status: 'CLOSED');
      expect((await api.fetchShowDetail(7)).status, ShowStatus.closed);

      givenWorkingServer(status: 'CANCELED');
      expect((await api.fetchShowDetail(7)).status, ShowStatus.canceled);

      givenWorkingServer(status: 'SOLD_OUT');
      // 매진은 끝난 것이 아니다. 취소표가 돌아올 수 있어 들어가 볼 수 있다.
      expect((await api.fetchShowDetail(7)).status, ShowStatus.soldOut);
    });

    test('예매 가능 여부와 막힌 사유를 읽는다', () async {
      givenWorkingServer(bookable: false, blockReason: 'NOT_ON_SALE');
      var detail = await api.fetchShowDetail(7);
      expect(detail.bookable, isFalse);
      expect(detail.blockReason, ShowBlockReason.notOnSale);

      // 서버의 `CLOSED` 는 공연 종료가 아니라 예매 마감이다.
      givenWorkingServer(bookable: false, blockReason: 'CLOSED');
      detail = await api.fetchShowDetail(7);
      expect(detail.blockReason, ShowBlockReason.bookingClosed);

      givenWorkingServer();
      detail = await api.fetchShowDetail(7);
      expect(detail.bookable, isTrue);
      expect(detail.blockReason, isNull);
    });

    // 사유를 못 읽었다고 예매를 막으면, 서버가 사유를 하나 늘린 날 멀쩡한
    // 공연이 앱에서만 닫힌다. 정말 못 파는 공연이면 좌석을 잡을 때 거절된다.
    test('예매 가능 여부가 빠졌거나 모르는 사유면 막지 않는다', () async {
      final json = concertJson()
        ..remove('bookable')
        ..remove('blockReason');
      givenServer((_) => jsonResponse(json));

      var detail = await api.fetchShowDetail(7);
      expect(detail.bookable, isTrue);
      expect(detail.blockReason, isNull);

      givenWorkingServer(bookable: false, blockReason: 'SOMETHING_NEW');
      detail = await api.fetchShowDetail(7);
      expect(detail.blockReason, isNull);
    });

    test('모르는 상태는 예매 중으로 본다', () async {
      givenWorkingServer(status: 'PAUSED');

      final detail = await api.fetchShowDetail(7);

      // 팔고 있는 공연에 '종료' 가 붙는 쪽이 못 파는 공연을 열어 두는 쪽보다
      // 나쁘다. 정말 못 파는 공연이면 서버가 예매 단계에서 막는다.
      expect(detail.status, ShowStatus.onSale);
    });
  });

  group('실패', () {
    test('없는 공연은 서버 문구를 그대로 던진다', () async {
      givenServer(
        (_) => problemResponse(
          status: 404,
          errorMessage: '공연을 찾을 수 없습니다. (concertId=99)',
          exception: 'ConcertNotFoundException',
        ),
      );

      await expectLater(
        api.fetchShowDetail(99),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.message, 'message', contains('공연을 찾을 수 없습니다')),
        ),
      );
    });

    test('JSON 이 아닌 응답은 화면용 문구로 바꾼다', () async {
      givenServer(
        (_) =>
            ResponseBody.fromString('<html>gateway</html>', 200, headers: {}),
      );

      await expectLater(
        api.fetchShowDetail(7),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('서버 응답을 읽을 수 없어요'),
          ),
        ),
      );
    });
  });
}
