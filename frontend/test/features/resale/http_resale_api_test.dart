import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/constants.dart';
import 'package:timo/features/resale/data/http_resale_api.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/models/trade_status.dart';

import '../../core/network/fake_http_adapter.dart';

/// 마켓 API(v1)에 맞는 요청이 나가고 응답을 제대로 읽는지. 서버 없이
/// [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpResaleApi api;

  /// [handler] 가 돌려주는 응답으로 가짜 서버를 세운다. [clock] 은 응답을 받은
  /// 기기 시각을 고정할 때만 준다.
  void givenServer(
    FutureOr<ResponseBody> Function(RecordedRequest) handler, {
    DateTime Function() clock = DateTime.now,
  }) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpResaleApi(dio: dio, clock: clock);
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

  group('운영 시간', () {
    test('운영 시간 주소로 GET 하고, 응답을 받은 기기 시각을 함께 든다', () async {
      final received = DateTime(2026, 9, 17, 21, 25, 20);
      givenServer(
        (_) => jsonResponse({
          'open': true,
          'serverTime': '2026-09-17T21:25:17',
          'opensAt': '2026-09-17T20:00:00',
          'closesAt': '2026-09-17T23:59:59',
        }),
        clock: () => received,
      );

      final hours = await api.fetchMarketHours();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/market/hours');
      expect(hours.isOpen, isTrue);
      expect(hours.serverTime, DateTime(2026, 9, 17, 21, 25, 17));
      expect(hours.opensAt, DateTime(2026, 9, 17, 20));
      expect(hours.closesAt, DateTime(2026, 9, 17, 23, 59, 59));
      expect(hours.receivedAt, received);
    });
  });

  group('운영 시간 거절', () {
    // 서버 문구 뒤에 `(opensAt=...)` 가 날것으로 붙어 온다. 스낵바든 목록의 오류
    // 화면이든 받는 쪽이 그대로 보여도 되게, 요청 계층에서 앱 문구로 바꾼다.
    test('닫혀 있어서 거절된 문구는 앱 문구로 바뀌고 예외 이름은 남는다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '양도 마켓 운영 시간이 아닙니다. (opensAt=2026-09-18T20:00:00)',
          exception: 'MarketClosedException',
        ),
      );

      await expectLater(
        api.fetchConcerts(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having(
                (e) => e.message,
                'message',
                ResaleStrings.marketClosedError,
              )
              .having(
                (e) => e.exceptionName,
                'exceptionName',
                'MarketClosedException',
              ),
        ),
      );
    });

    test('열려 있어서 거절된 가격 수정 문구도 앱 문구로 바뀐다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage:
              '운영 시간 중에는 등록가를 바꿀 수 없습니다. (closesAt=2026-09-17T23:59:59)',
          exception: 'MarketOpenException',
        ),
      );

      await expectLater(
        api.updateListingPrice(listingId: 8, price: 120000),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            ResaleStrings.marketOpenError,
          ),
        ),
      );
    });
  });

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

  group('구매', () {
    /// 서버 체결 응답 한 건. 실제 `PurchaseResponseDto` 모양이다.
    Map<String, dynamic> purchaseJson() => {
      'tradeId': 42,
      'listingId': 6,
      'status': 'CONFIRMED',
      'price': 132000,
      'concertTitle': '2026 REMIND: 리센느',
      'venueName': '올림픽공원 체조경기장',
      'sectionName': 'R석',
      'tradedAt': '2026-09-17T21:10:00',
      'startDate': '2026-10-10T19:00:00',
      'seatNo': 12,
      'seatCol': 24,
    };

    test('본 금액과 멱등키를 실어 보내고 확정된 체결을 받는다', () async {
      givenServer((_) => jsonResponse(purchaseJson()));

      final trade = await api.purchase(
        listingId: 6,
        expectedPrice: 132000,
        idempotencyKey: 'once',
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/market/listings/6/purchase');
      expect(request.rawBody, contains('132000'));
      expect(request.headers['Idempotency-Key'], 'once');
      // 체결이 끝나야 응답이 오므로 상태는 언제나 확정이다.
      expect(trade.tradeId, 42);
      expect(trade.status, TradeStatus.confirmed);
    });

    // 서버는 온체인 체결(최대 30초)이 끝나야 답한다. 기본 대기(10초)로 끊으면
    // 결제와 양도는 끝났는데 앱만 실패로 읽는다.
    test('서버의 온체인 대기보다 오래 기다린다', () async {
      givenServer((_) => jsonResponse(purchaseJson()));

      await api.purchase(
        listingId: 6,
        expectedPrice: 132000,
        idempotencyKey: 'once',
      );

      expect(
        adapter.requests.single.options.receiveTimeout,
        ResaleMetrics.onChainTimeout,
      );
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
      // 취소도 체인을 탄다(백엔드 `TicketNftClient.delistFor`). 기본 대기로
      // 끊으면 취소는 끝났는데 앱만 실패로 돌아선다.
      expect(request.options.receiveTimeout, ResaleMetrics.onChainTimeout);
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
    /// 서버 내 티켓 목록 응답 한 건. 실제 `MyTicketSummaryResponseDto` 모양이다.
    Map<String, dynamic> myTicketJson({
      int ticketId = 501,
      String ticketStatus = 'OWNED',
      bool listed = false,
      String acquiredBy = 'BOOKING',
    }) => {
      'ticketId': ticketId,
      'reservationId': ticketId - 500,
      'concertId': 11,
      'concertTitle': '2026 REMIND: 리센느',
      'posterImageUrl': 'poster/remind.gif',
      'startDate': '2026-10-10T19:00:00',
      'venueName': '올림픽공원 체조경기장',
      'sectionName': 'R석',
      'seatNo': 12,
      'seatCol': 24,
      'facePrice': 154000,
      'ticketStatus': ticketStatus,
      'acquiredBy': acquiredBy,
      'acquiredAt': '2026-09-01T20:05:00',
      'listed': listed,
    };

    // 예매 번호(reservationId)와 티켓 번호(ticketId)는 다른 값이다. 바꿔
    // 읽으면 등록이 서버에서 거절된다.
    test('내 티켓 목록에서 팔 수 있는 것만 골라 티켓 번호로 읽는다', () async {
      givenServer(
        (_) => jsonResponse(
          paged([
            myTicketJson(ticketId: 501),
            // 이미 마켓에 올렸다. 다시 등록하면 서버가 거절한다.
            myTicketJson(ticketId: 502, ticketStatus: 'LISTED', listed: true),
            // 발행이 아직이다.
            myTicketJson(ticketId: 503, ticketStatus: 'PENDING_MINT'),
            // 회수됐다.
            myTicketJson(ticketId: 504, ticketStatus: 'REVOKED'),
          ]),
        ),
      );

      final tickets = await api.fetchListableTickets();

      expect(adapter.requests.single.path, '/api/v1/tickets/me');
      final ticket = tickets.single;
      expect(ticket.ticketId, 501);
      expect(ticket.facePrice, 154000);
      expect(ticket.seatLabel, 'R석 12열 24번');
    });

    // 소유 기준 목록이라 양도로 받은 티켓도 후보에 들어온다.
    test('양도로 받은 보유 티켓도 다시 팔 수 있다', () async {
      givenServer(
        (_) => jsonResponse(
          paged([myTicketJson(ticketId: 505, acquiredBy: 'TRANSFER')]),
        ),
      );

      final tickets = await api.fetchListableTickets();

      expect(tickets.single.ticketId, 505);
    });

    // 상태값이 아직 보유인데 매물 테이블에만 올라간 찰나도 있다. 백엔드 주석은
    // `listed` 를 기준으로 삼으라고 한다.
    test('상태가 보유라도 listed 가 켜져 있으면 뺀다', () async {
      givenServer(
        (_) => jsonResponse(paged([myTicketJson(ticketId: 506, listed: true)])),
      );

      expect(await api.fetchListableTickets(), isEmpty);
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
      // 등록도 체인을 탄다. 기본 대기로 끊으면 매물은 올라갔는데 앱만 실패로
      // 돌아서고, 다시 올리면 "등록할 수 있는 상태가 아니다" 를 받는다.
      expect(request.options.receiveTimeout, ResaleMetrics.onChainTimeout);
    });
  });
}
