import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/models/my_trade.dart';

/// 목이 내 거래 내역과 등록 취소를 서버처럼 움직이는지. 양도 목록 탭은 앱
/// 기본값인 이 목으로 확인하므로, 목이 흐름을 틀리게 흉내 내면 화면 테스트가
/// 통과해도 실제 서버에서 어긋난다.
void main() {
  final now = DateTime(2026, 9, 16, 12);

  MockResaleApi apiOf({
    ResaleMockScenario scenario = ResaleMockScenario.design,
  }) => MockResaleApi(
    latency: Duration.zero,
    scenario: scenario,
    clock: () => now,
  );

  group('내 거래 내역', () {
    test('시안 데이터는 판매 중인 내 매물 하나와 팔린 내 매물 하나다', () async {
      final trades = await apiOf().fetchMyTrades();

      expect(trades.every((trade) => trade.isSale), isTrue);
      expect(trades.where((t) => t.isOnSale).map((t) => t.listingId), [8]);
      expect(trades.where((t) => t.status == MyTradeStatus.sold), hasLength(1));
    });

    test('최근 것부터 온다', () async {
      final trades = await apiOf().fetchMyTrades();

      for (var i = 1; i < trades.length; i++) {
        expect(
          trades[i - 1].occurredAt.isBefore(trades[i].occurredAt),
          isFalse,
        );
      }
    });

    test('산 티켓은 구매로 들어오고 체결 번호가 있다', () async {
      final api = apiOf();
      final bought = await api.purchase(
        listingId: 1,
        expectedPrice: 176000,
        idempotencyKey: 'once',
      );

      final trades = await api.fetchMyTrades();

      final purchase = trades.singleWhere(
        (trade) => trade.type == MyTradeType.purchase,
      );
      expect(purchase.tradeId, bought.tradeId);
      expect(purchase.listingId, 1);
      expect(purchase.status, MyTradeStatus.pending);
      // 산 티켓은 매물이 아니다. 양도 목록 탭이 세지 않는다.
      expect(purchase.isOnSale, isFalse);
      // 방금 샀으니 맨 위다.
      expect(trades.first.tradeId, bought.tradeId);
    });

    test('빈 시나리오는 빈 목록이다', () async {
      final api = apiOf(scenario: ResaleMockScenario.empty);

      expect(await api.fetchMyTrades(), isEmpty);
    });
  });

  group('등록 취소', () {
    test('내리면 내 거래 내역에서 취소함으로 바뀌고 마켓에서 사라진다', () async {
      final api = apiOf();

      await api.cancelListing(8);

      final mine = (await api.fetchMyTrades()).singleWhere(
        (trade) => trade.listingId == 8,
      );
      expect(mine.status, MyTradeStatus.canceled);
      expect(mine.isOnSale, isFalse);
      // 8번은 4번 공연의 유일한 매물이었다.
      expect(await api.fetchListings(4), isEmpty);
    });

    test('등록했다 내리면 티켓이 등록 화면 목록으로 돌아온다', () async {
      final api = apiOf();
      final listed = await api.createListing(ticketId: 101, price: 190000);
      expect((await api.fetchListableTickets()).map((t) => t.ticketId), [102]);

      await api.cancelListing(listed.listingId);

      expect(
        (await api.fetchListableTickets()).map((t) => t.ticketId),
        containsAll([101, 102]),
      );
    });

    test('남의 매물은 403, 이미 닫힌 매물은 409 다', () async {
      final api = apiOf();

      await expectLater(
        api.cancelListing(1),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      await expectLater(
        api.cancelListing(9),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
    });
  });

  group('가격 수정', () {
    test('바꾸면 내 거래 내역과 마켓 목록의 가격이 함께 바뀌고 매물 번호는 그대로다', () async {
      final api = apiOf();

      final detail = await api.updateListingPrice(listingId: 8, price: 120000);

      expect(detail.listingId, 8);
      expect(detail.price, 120000);
      final mine = (await api.fetchMyTrades()).singleWhere(
        (trade) => trade.listingId == 8,
      );
      expect(mine.price, 120000);
      expect(mine.isOnSale, isTrue);
      expect((await api.fetchListings(4)).single.price, 120000);
    });

    test('남의 매물은 403, 닫힌 매물은 409, 정가 초과는 400 이다', () async {
      final api = apiOf();

      await expectLater(
        api.updateListingPrice(listingId: 1, price: 100000),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      await expectLater(
        api.updateListingPrice(listingId: 9, price: 100000),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
      // 8번의 정가는 143,000 이다.
      await expectLater(
        api.updateListingPrice(listingId: 8, price: 143001),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
      );
    });
  });
}
