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
  Map<String, dynamic> concertJson({String status = 'ON_SALE'}) => {
    'id': 7,
    'title': '김필 단독 콘서트',
    'genre': 'CONCERT',
    'posterImageUrl': 'poster/poster_main_kim_feel.gif',
    'imageUrls': ['detail/poster_detail_kim.jpg'],
    'description': '김필 단독 콘서트',
    'ageRating': 'AGE_7',
    'status': status,
    'viewCount': 1203,
    'startDate': '2026-10-10T19:00:00',
    // 종료일이 시작일과 다르게 와도 화면은 하루만 쓴다.
    'endDate': '2026-10-12T21:00:00',
    'openAt': '2026-09-01T20:00:00',
    'venueId': 1,
    'venueName': '고척돔',
    'artists': [
      {'id': 1, 'name': '김필', 'profileImage': 'artist/artist_kim_feel.jpg'},
    ],
  };

  /// 구역 목록 응답. 가격은 여기에만 있다.
  Map<String, dynamic> sectionsJson() => {
    'venueId': 1,
    'venueName': '고척돔',
    'totalSeatCount': 400,
    'totalAvailableCount': 300,
    'sections': [
      {
        'id': 1,
        'name': '1층 A블록',
        'grade': 'COMMON',
        'price': 150000,
        'seatCount': 200,
        'availableCount': 199,
        'rowCount': 10,
        'seatPerRow': 20,
      },
      {
        'id': 3,
        'name': '2층 C블록',
        'grade': 'COMMON',
        'price': 120000,
        'seatCount': 200,
        'availableCount': 200,
        'rowCount': 10,
        'seatPerRow': 20,
      },
    ],
  };

  /// 공연과 구역을 모두 제대로 돌려주는 서버.
  void givenWorkingServer({String status = 'ON_SALE'}) {
    givenServer(
      (request) => request.path.startsWith('/api/v1/concerts')
          ? jsonResponse(concertJson(status: status))
          : jsonResponse(sectionsJson()),
    );
  }

  group('요청', () {
    test('공연은 번호를 주소에, 구역은 조건에 실어 함께 묻는다', () async {
      givenWorkingServer();

      await api.fetchShowDetail(7);

      expect(adapter.requests, hasLength(2));
      final concert = adapter.requests.first;
      expect(concert.method, 'GET');
      expect(concert.path, '/api/v1/concerts/7');

      // 가격은 공연 응답에 없어서 구역을 한 번 더 묻는다.
      final sections = adapter.requests.last;
      expect(sections.method, 'GET');
      expect(sections.path, '/api/v1/sections');
      expect(sections.query['concertId'], '7');
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
    });

    test('가격을 구역 순서대로 세운다', () async {
      givenWorkingServer();

      final prices = (await api.fetchShowDetail(7)).zonePrices;

      // 등급으로 묶지 않는다. 서버 등급이 하나뿐이라 묶으면 한 줄이 된다.
      expect(prices, hasLength(2));
      expect(prices.first.zoneName, '1층 A블록');
      expect(prices.first.price, 150000);
      expect(prices.last.zoneName, '2층 C블록');
    });

    test('공연일은 하루만 쓴다', () async {
      givenWorkingServer();

      final detail = await api.fetchShowDetail(7);

      // 서버는 종료일(10/12)도 주지만 단일 회차 공연이라 읽지 않는다.
      expect(detail.dateLabel, '2026.10.10');
    });

    test('끝난 공연과 취소된 공연을 구분한다', () async {
      givenWorkingServer(status: 'CLOSED');
      expect((await api.fetchShowDetail(7)).isFinished, isTrue);

      givenWorkingServer(status: 'CANCELED');
      expect((await api.fetchShowDetail(7)).isFinished, isTrue);

      givenWorkingServer(status: 'SOLD_OUT');
      // 매진은 끝난 것이 아니다. 취소표가 돌아올 수 있어 들어가 볼 수 있다.
      expect((await api.fetchShowDetail(7)).isFinished, isFalse);
    });

    test('모르는 상태는 예매 중으로 본다', () async {
      givenWorkingServer(status: 'PAUSED');

      final detail = await api.fetchShowDetail(7);

      // 팔고 있는 공연에 '종료' 가 붙는 쪽이 못 파는 공연을 열어 두는 쪽보다
      // 나쁘다. 정말 못 파는 공연이면 서버가 예매 단계에서 막는다.
      expect(detail.status, ShowStatus.onSale);
      expect(detail.isFinished, isFalse);
    });
  });

  group('실패', () {
    test('구역을 못 받아도 공연은 그린다', () async {
      // 구역 조회는 로그인해야 열린다. 로그인 전 사용자도 상세는 볼 수 있어야 한다.
      givenServer(
        (request) => request.path.startsWith('/api/v1/concerts')
            ? jsonResponse(concertJson())
            : problemResponse(
                status: 401,
                errorMessage: '인증 정보가 올바르지 않습니다. 다시 로그인해 주세요.',
                exception: 'TokenInvalidException',
              ),
      );

      final detail = await api.fetchShowDetail(7);

      expect(detail.title, '김필 단독 콘서트');
      expect(detail.zonePrices, isEmpty);
    });

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
