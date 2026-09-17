import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/data/http_resale_api.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/models/trade_status.dart';

import '../../core/network/fake_http_adapter.dart';

/// 내 거래 내역·등록 취소·가격 수정이 마켓 API(v1)에 맞는 요청을 보내고 응답을
/// 제대로 읽는지. 서버 없이 [FakeHttpAdapter] 로 검사한다. 조회·구매는 화면
/// 테스트가 목으로 덮고 있어, 여기서는 양도 목록 탭이 얹은 요청과 그 위로
/// 옮긴 체결 상태 확인, 그리고 예매 응답에서 등록 번호를 꺼내는 자리를 본다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpResaleApi api;

  /// [handler] 가 돌려주는 응답으로 가짜 서버를 세운다.
  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpResaleApi(dio: dio);
  }

  /// 서버 내 거래 내역 응답 한 건. 실제 `MyTradeSummaryResponseDto` 모양이다.
  Map<String, dynamic> tradeJson({
    String type = 'SALE',
    int? tradeId,
    int listingId = 6,
    String status = 'LISTED',
  }) => {
    'type': type,
    'tradeId': tradeId,
    'listingId': listingId,
    'status': status,
    'concertId': 11,
    'concertTitle': '2026 REMIND: 리센느',
    'posterImageUrl': 'poster/remind.gif',
    'startDate': '2026-10-10T19:00:00',
    'venueName': '올림픽공원 체조경기장',
    'sectionName': 'R석',
    'grade': 'R',
    // seatNo 가 행(열), seatCol 이 그 행 안의 자리 번호다.
    'seatNo': 12,
    'seatCol': 24,
    'price': 123000,
    'faceValue': 154000,
    'occurredAt': '2026-09-13T20:10:00',
  };

  /// Spring `PagedModel` 로 감싼다.
  Map<String, dynamic> paged(List<Map<String, dynamic>> content) => {
    'content': content,
    'page': {
      'size': 100,
      'number': 0,
      'totalElements': content.length,
      'totalPages': 1,
    },
  };

  group('내 거래 내역', () {
    test('내 거래 내역 주소로 GET 하고 한 번에 다 받는다', () async {
      givenServer((_) => jsonResponse(paged([tradeJson()])));

      await api.fetchMyTrades();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/market/listings/me');
      expect(request.query['size'], '100');
    });

    test('판매와 구매가 섞인 응답을 순서대로 읽는다', () async {
      givenServer(
        (_) => jsonResponse(
          paged([
            tradeJson(),
            tradeJson(
              type: 'PURCHASE',
              tradeId: 42,
              listingId: 7,
              status: 'PENDING',
            ),
          ]),
        ),
      );

      final trades = await api.fetchMyTrades();

      expect(trades, hasLength(2));
      expect(trades.first.type, MyTradeType.sale);
      expect(trades.first.isOnSale, isTrue);
      expect(trades.first.seatLabel, 'R석 12열 24번');
      expect(trades.first.startAt, DateTime(2026, 10, 10, 19));
      expect(trades.last.type, MyTradeType.purchase);
      expect(trades.last.tradeId, 42);
      expect(trades.last.status, MyTradeStatus.pending);
    });

    test('빈 목록은 정상 결과다', () async {
      givenServer((_) => jsonResponse(paged([])));

      expect(await api.fetchMyTrades(), isEmpty);
    });

    test('content 가 없는 응답이면 안내 문구로 바꾼다', () async {
      givenServer((_) => jsonResponse({'page': {}}));

      expect(() => api.fetchMyTrades(), throwsA(isA<ApiException>()));
    });
  });

  group('체결 상태 확인', () {
    // 폴링 전용 주소가 없어 내 거래 내역에서 골라낸다. 이 작업이 그 메서드를
    // 목록 모델 위로 옮겼으니 결과가 그대로인지 본다.
    test('같은 체결 번호의 상태를 돌려준다', () async {
      givenServer(
        (_) => jsonResponse(
          paged([
            tradeJson(),
            tradeJson(
              type: 'PURCHASE',
              tradeId: 42,
              listingId: 7,
              status: 'CONFIRMED',
            ),
          ]),
        ),
      );

      expect(await api.fetchTradeStatus(42), TradeStatus.confirmed);
    });

    test('목록에 아직 없으면 진행 중으로 본다', () async {
      givenServer((_) => jsonResponse(paged([tradeJson()])));

      expect(await api.fetchTradeStatus(99), TradeStatus.pending);
    });
  });

  group('등록 취소', () {
    test('매물 번호로 취소 주소에 POST 하고 빈 응답을 받아들인다', () async {
      givenServer((_) => emptyResponse());

      await api.cancelListing(6);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/market/listings/6/cancel');
      expect(request.rawBody, isNull);
    });

    // 취소 조건은 서버가 최종 판정한다. 화면이 미리 걸러도 시점 차이로 통과할
    // 수 있다 — 예매 취소와 같은 규칙이다.
    test('서버가 거절하면 그 문구와 예외 이름을 그대로 올린다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '이미 닫힌 매물입니다.',
          exception: 'ListingAlreadyClosedException',
        ),
      );

      await expectLater(
        api.cancelListing(6),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', '이미 닫힌 매물입니다.')
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                'ListingAlreadyClosedException',
              ),
        ),
      );
    });

    test('연결이 끊기면 ApiException', () async {
      givenServer(
        (request) => throw DioException.connectionError(
          requestOptions: request.options,
          reason: 'offline',
        ),
      );

      await expectLater(
        api.cancelListing(6),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '인터넷 연결을 확인해주세요.',
          ),
        ),
      );
    });
  });

  group('가격 수정', () {
    /// 서버 매물 상세 응답. 실제 `ListingDetailResponseDto` 모양이다.
    Map<String, dynamic> detailJson({int price = 110000}) => {
      'listingId': 6,
      'status': 'LISTED',
      'concertId': 11,
      'concertTitle': '2026 REMIND: 리센느',
      'posterImageUrl': 'poster/remind.gif',
      'startDate': '2026-10-10T19:00:00',
      'venueName': '올림픽공원 체조경기장',
      'sectionName': 'R석',
      'seatNo': 12,
      'seatCol': 24,
      'price': price,
      'faceValue': 154000,
      'discountRate': 28,
      'mine': true,
      'listedAt': '2026-09-13T20:10:00',
      'closedAt': null,
    };

    // 절댓값을 넣는 요청이라 PATCH 다. 재시도가 안전해야 한다(백엔드 MarketApi).
    test('매물 번호로 가격 주소에 PATCH 하고 새 가격만 보낸다', () async {
      givenServer((_) => jsonResponse(detailJson()));

      final detail = await api.updateListingPrice(listingId: 6, price: 110000);

      final request = adapter.requests.single;
      expect(request.method, 'PATCH');
      expect(request.path, '/api/v1/market/listings/6/price');
      expect(request.jsonBody, {'price': 110000});
      expect(detail.listingId, 6);
      expect(detail.price, 110000);
    });

    test('서버가 거절하면 그 문구를 그대로 올린다', () async {
      givenServer(
        (_) => problemResponse(
          status: 400,
          errorMessage: '등록가는 정가를 넘을 수 없습니다.',
          exception: 'ListPriceExceedsFacePriceException',
        ),
      );

      await expectLater(
        api.updateListingPrice(listingId: 6, price: 200000),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.message, 'message', '등록가는 정가를 넘을 수 없습니다.'),
        ),
      );
    });
  });

  group('등록 가능한 티켓', () {
    /// 서버 예매 목록 응답 한 건. 실제 `ReservationSummaryResponseDto` 모양이다.
    Map<String, dynamic> reservationJson({
      int id = 1,
      int ticketId = 501,
      String status = 'PAID',
    }) => {
      'id': id,
      'ticketId': ticketId,
      'concertId': 11,
      'concertTitle': '2026 REMIND: 리센느',
      'posterImageUrl': 'poster/remind.gif',
      'startDate': '2026-10-10T19:00:00',
      'venueName': '올림픽공원 체조경기장',
      'sectionName': 'R석',
      'seatNo': 12,
      'seatCol': 24,
      'facePrice': 154000,
      'status': status,
      'createdAt': '2026-09-01T20:05:00',
    };

    // 예매 번호(id)와 티켓 번호(ticketId)는 다른 값이다. 바꿔 읽으면 등록이
    // 서버에서 거절된다 — 이 작업 전까지 그랬다.
    test('예매 목록에서 손에 있는 것만 골라 티켓 번호로 읽는다', () async {
      givenServer(
        (_) => jsonResponse(
          paged([
            reservationJson(id: 1, ticketId: 501),
            reservationJson(id: 2, ticketId: 502, status: 'CANCELLED'),
          ]),
        ),
      );

      final tickets = await api.fetchListableTickets();

      expect(adapter.requests.single.path, '/api/v1/reservations');
      final ticket = tickets.single;
      expect(ticket.ticketId, 501);
      expect(ticket.facePrice, 154000);
      expect(ticket.seatLabel, 'R석 12열 24번');
    });

    test('등록은 티켓 번호와 가격을 보낸다', () async {
      givenServer(
        (_) => jsonResponse({
          'listingId': 6,
          'status': 'LISTED',
          'concertId': 11,
          'concertTitle': '2026 REMIND: 리센느',
          'venueName': '올림픽공원 체조경기장',
          'sectionName': 'R석',
          'seatNo': 12,
          'seatCol': 24,
          'price': 120000,
          'faceValue': 154000,
          'discountRate': 22,
          'mine': true,
          'listedAt': '2026-09-13T20:10:00',
        }, status: 201),
      );

      await api.createListing(ticketId: 501, price: 120000);

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/market/listings');
      expect(request.jsonBody, {'ticketId': 501, 'price': 120000});
    });
  });
}
