import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/data/http_resale_api.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/models/trade_status.dart';

import '../../core/network/fake_http_adapter.dart';

/// 내 거래 내역·등록 취소가 마켓 API 에 맞는 요청을 보내고 응답을 제대로 읽는지.
/// 서버 없이 [FakeHttpAdapter] 로 검사한다. 조회·구매·등록은 화면 테스트가
/// 목으로 덮고 있어, 여기서는 양도 목록 탭이 얹은 요청과 그 위로 옮긴 체결
/// 상태 확인만 본다.
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
      expect(request.path, '/api/v0/market/listings/me');
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
      expect(request.path, '/api/v0/market/listings/6/cancel');
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
}
