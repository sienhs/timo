import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/utils/market_error.dart';

/// 목이 내 거래 내역과 등록 취소를 서버처럼 움직이는지. 양도 목록 탭은 앱
/// 기본값인 이 목으로 확인하므로, 목이 흐름을 틀리게 흉내 내면 화면 테스트가
/// 통과해도 실제 서버에서 어긋난다.
void main() {
  /// 마켓이 열려 있는 시각과 닫혀 있는 시각. 목도 서버처럼 공연 목록·매물
  /// 목록·구매는 열린 시간에만, 가격 수정은 닫힌 시간에만 받으므로 흐름마다
  /// 맞는 시각에 둔다.
  final whileOpen = DateTime(2026, 9, 16, 21);
  final whileClosed = DateTime(2026, 9, 16, 3);

  MockResaleApi apiOf({
    ResaleMockScenario scenario = ResaleMockScenario.design,
    DateTime Function()? clock,
  }) => MockResaleApi(
    latency: Duration.zero,
    scenario: scenario,
    clock: clock ?? () => whileOpen,
  );

  group('운영 시간', () {
    MockResaleApi at(DateTime clock) =>
        MockResaleApi(latency: Duration.zero, clock: () => clock);

    test('08:00~23:00 에는 열려 있고 그날 창의 시각을 준다', () async {
      final hours = await at(
        DateTime(2026, 9, 16, 21, 25, 17),
      ).fetchMarketHours();

      expect(hours.isOpen, isTrue);
      expect(hours.serverTime, DateTime(2026, 9, 16, 21, 25, 17));
      expect(hours.opensAt, DateTime(2026, 9, 16, 8));
      expect(hours.closesAt, DateTime(2026, 9, 16, 23));
      // 시차가 없는 서버다.
      expect(hours.receivedAt, hours.serverTime);
    });

    test('여는 시각 전이면 닫혀 있고 그날 오픈을 준다', () async {
      final hours = await at(DateTime(2026, 9, 16, 6, 37)).fetchMarketHours();

      expect(hours.isOpen, isFalse);
      expect(hours.opensAt, DateTime(2026, 9, 16, 8));
    });

    test('창이 끝난 뒤면 다음 날 창을 준다', () async {
      final hours = await at(
        DateTime(2026, 9, 16, 23, 59, 59, 500),
      ).fetchMarketHours();

      expect(hours.isOpen, isFalse);
      expect(hours.opensAt, DateTime(2026, 9, 17, 8));
      expect(hours.closesAt, DateTime(2026, 9, 17, 23));
    });

    Matcher rejectedAs(String exceptionName) => throwsA(
      isA<ApiException>()
          .having((e) => e.status, 'status', 409)
          .having((e) => e.exceptionName, 'exceptionName', exceptionName),
    );

    test('닫혀 있으면 공연 목록·매물 목록·구매를 409 로 거절하고, 등록·취소·내 내역은 받는다', () async {
      final api = at(whileClosed);
      final closed = rejectedAs(marketClosedExceptionName);

      await expectLater(api.fetchConcerts(), closed);
      await expectLater(api.fetchListings(1), closed);
      await expectLater(
        api.purchase(listingId: 1, expectedPrice: 1, idempotencyKey: 'k'),
        closed,
      );

      // 닫힌 시간에 올린 매물도 바로 등록된다. 다음 오픈에 목록으로 드러난다.
      final listed = await api.createListing(ticketId: 101, price: 100000);
      expect(listed.price, 100000);
      await api.cancelListing(8);
      expect(await api.fetchMyTrades(), isNotEmpty);
    });

    test('열려 있으면 가격 수정만 409 로 거절한다', () async {
      await expectLater(
        at(whileOpen).updateListingPrice(listingId: 8, price: 100000),
        rejectedAs(marketOpenExceptionName),
      );
    });

    // 매물은 등록 즉시 마켓에 올라간다(서버 `listing-delay-enabled` 꺼짐).
    // 열린 시간에 올리면 바로 목록에 있고, 내 거래 내역에도 있다.
    test('오늘 등록한 매물은 바로 목록과 내 거래 내역에 있다', () async {
      final api = MockResaleApi(latency: Duration.zero, clock: () => whileOpen);
      final listed = await api.createListing(ticketId: 101, price: 190000);

      expect(
        (await api.fetchListings(listed.concertId)).map((l) => l.listingId),
        contains(listed.listingId),
      );
      expect(
        (await api.fetchMyTrades()).map((t) => t.listingId),
        contains(listed.listingId),
      );
    });
  });

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
      // 체결이 끝나야 응답이 오므로 내 거래 내역에도 확정으로 들어온다.
      expect(purchase.status, MyTradeStatus.confirmed);
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
      // 가격은 닫힌 시간에 바꾸고, 바뀐 값은 다음 창이 열린 뒤 목록에서 본다.
      var now = whileClosed;
      final api = apiOf(clock: () => now);

      final detail = await api.updateListingPrice(listingId: 8, price: 120000);

      expect(detail.listingId, 8);
      expect(detail.price, 120000);
      final mine = (await api.fetchMyTrades()).singleWhere(
        (trade) => trade.listingId == 8,
      );
      expect(mine.price, 120000);
      expect(mine.isOnSale, isTrue);

      now = whileOpen;
      expect((await api.fetchListings(4)).single.price, 120000);
    });

    test('남의 매물은 403, 닫힌 매물은 409, 정가 초과는 400 이다', () async {
      final api = apiOf(clock: () => whileClosed);

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
