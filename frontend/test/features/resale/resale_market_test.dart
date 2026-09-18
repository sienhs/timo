import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/resale/constants.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/data/resale_api.dart';
import 'package:timo/features/resale/models/listable_ticket.dart';
import 'package:timo/features/resale/models/listing.dart';
import 'package:timo/features/resale/models/listing_detail.dart';
import 'package:timo/features/resale/models/market_concert.dart';
import 'package:timo/features/resale/models/market_hours.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/models/purchased_trade.dart';
import 'package:timo/features/resale/models/trade_status.dart';
import 'package:timo/features/resale/screens/listing_purchase_complete_screen.dart';
import 'package:timo/features/resale/screens/listing_purchase_screen.dart';
import 'package:timo/features/resale/screens/listing_register_screen.dart';
import 'package:timo/features/resale/screens/market_concerts_screen.dart';
import 'package:timo/features/resale/screens/market_listings_screen.dart';
import 'package:timo/features/resale/state/resale_api_scope.dart';
import 'package:timo/features/resale/widgets/listable_ticket_card.dart';
import 'package:timo/features/resale/widgets/listing_row_card.dart';
import 'package:timo/features/resale/widgets/market_concert_card.dart';
import 'package:timo/routes/app_routes.dart';

/// 마켓이 열려 있는 시각과 닫혀 있는 시각. 열림 판정은 가짜 서버(목)가 제
/// 시계로 하므로, 화면과 목에 같은 시각을 고정해 넣는다.
final _whileOpen = DateTime(
  2026,
  5,
  20,
  MockResaleApi.opensAtHour,
).add(const Duration(minutes: 30));
final _whileClosed = DateTime(2026, 5, 20, 16, 37);

void main() {
  /// 홈 라우트는 뺀다. 이 화면들이 홈으로 돌아갈 일은 여기서 볼 게 아니고,
  /// 홈 셸은 제 스코프를 따로 요구한다(충전 화면 테스트와 같은 방식).
  final routes = Map.of(AppRoutes.routes)..remove(AppRoutes.home);

  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 응답과 화면 전환을 기다린다.
  ///
  /// `pumpAndSettle` 을 쓸 수 없다. 화면에 1초마다 도는 카운트다운이 있어
  /// 다시 그릴 일이 끊이지 않으므로, 정해진 만큼만 흘려 보낸다. 라우트 전환
  /// 애니메이션(300ms)이 끝날 만큼은 흘려야 새 화면의 위젯을 누를 수 있다.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 화면을 걷어 낸다. 카운트다운 타이머가 살아 있는 채로 테스트가 끝나면
  /// 프레임워크가 '아직 도는 타이머가 있다' 고 실패시킨다.
  Future<void> closeScreen(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  Future<AuthSession> pump(
    WidgetTester tester, {
    required ResaleApi api,
    required Widget home,
    bool loggedIn = true,
  }) async {
    usePhoneSize(tester);
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: ResaleApiScope(
          api: api,
          child: MaterialApp(theme: AppTheme.light, home: home, routes: routes),
        ),
      ),
    );
    await settle(tester);
    return session;
  }

  group('공연 선택', () {
    testWidgets('마켓이 열려 있으면 공연과 매물 수가 보인다', (tester) async {
      await pump(
        tester,
        api: MockResaleApi(latency: Duration.zero, clock: () => _whileOpen),
        home: MarketConcertsScreen(clock: () => _whileOpen),
      );

      expect(find.text(ResaleStrings.marketTitle), findsOneWidget);
      expect(find.text('2026 BIGBANG'), findsOneWidget);
      // 첫 공연에 매물 넷을 몰아 둔 목 데이터.
      expect(find.text(ResaleStrings.listingCount(4)), findsOneWidget);
      // 등록 입구는 늘 있고, 열려 있어도 올린 매물은 다음 날에 보인다고 알린다.
      expect(find.text(ResaleStrings.registerAction), findsOneWidget);
      expect(find.text(ResaleStrings.registerNotice('20:00')), findsOneWidget);

      await closeScreen(tester);
    });

    testWidgets('마켓이 닫혀 있으면 목록 대신 다음 오픈을 알리고, 등록은 열어 둔다', (tester) async {
      final api = _CountingResaleApi(
        MockResaleApi(latency: Duration.zero, clock: () => _whileClosed),
      );
      await pump(
        tester,
        api: api,
        home: MarketConcertsScreen(clock: () => _whileClosed),
      );

      expect(find.text(ResaleStrings.closedTitle), findsOneWidget);
      expect(find.text(ResaleStrings.closedNextOpen('20:00')), findsOneWidget);
      // 다음 오픈까지 남은 시간(16:37 -> 20:00).
      expect(find.text('03:23:00'), findsOneWidget);
      expect(find.byType(MarketConcertCard), findsNothing);
      // 닫혀 있는 동안에는 목록을 부르지도 않는다. 운영 상태만 묻는다.
      expect(api.concertCalls, 0);
      expect(api.hoursCalls, 1);

      // 등록은 닫혀 있어도 되므로 버튼이 살아 있고, 올린 매물이 언제 보이는지
      // 한 줄로 알린다.
      expect(find.text(ResaleStrings.registerNotice('20:00')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, ResaleStrings.registerAction),
            )
            .onPressed,
        isNotNull,
      );

      await closeScreen(tester);
    });

    testWidgets('로그인하지 않았으면 안내와 로그인 입구만 보인다', (tester) async {
      final api = _CountingResaleApi(
        MockResaleApi(latency: Duration.zero, clock: () => _whileOpen),
      );
      await pump(
        tester,
        api: api,
        home: MarketConcertsScreen(clock: () => _whileOpen),
        loggedIn: false,
      );

      expect(find.text(ResaleStrings.loginPrompt), findsOneWidget);
      expect(find.text(AuthStrings.login), findsOneWidget);
      expect(find.byType(MarketConcertCard), findsNothing);
      // 비로그인으로 부르면 401 만 받는다. 운영 상태도 목록도 아예 부르지 않는다.
      expect(api.hoursCalls, 0);
      expect(api.concertCalls, 0);

      await closeScreen(tester);
    });

    testWidgets('검색은 받아 둔 목록에서 제목으로 거른다', (tester) async {
      await pump(
        tester,
        api: MockResaleApi(latency: Duration.zero, clock: () => _whileOpen),
        home: MarketConcertsScreen(clock: () => _whileOpen),
      );

      await tester.enterText(find.byType(TextField), 'BTS');
      await settle(tester);

      expect(find.text('2026 BTS 콘서트'), findsOneWidget);
      expect(find.text('2026 BIGBANG'), findsNothing);

      await tester.enterText(find.byType(TextField), '없는 공연');
      await settle(tester);

      expect(find.text(ResaleStrings.searchEmpty('없는 공연')), findsOneWidget);

      await closeScreen(tester);
    });

    testWidgets('마감임박순을 고르면 임박한 공연이 맨 위로 온다', (tester) async {
      await pump(
        tester,
        api: MockResaleApi(latency: Duration.zero, clock: () => _whileOpen),
        home: MarketConcertsScreen(clock: () => _whileOpen),
      );

      String firstCardTitle() => tester
          .widgetList<MarketConcertCard>(find.byType(MarketConcertCard))
          .first
          .concert
          .title;

      // 기본은 인기순(매물이 많은 공연부터)이라 매물 넷짜리가 맨 위다.
      expect(firstCardTitle(), '2026 BIGBANG');

      await tester.tap(find.text(ResaleStrings.sortDeadline));
      await settle(tester);

      // 목 데이터에서 가장 임박한 공연도 같은 공연이라, 순서가 바뀌는 쪽을
      // 본다 — 매물 둘짜리(BTS)가 매물 하나짜리(블랙핑크)보다 뒤로 간다.
      final titles = tester
          .widgetList<MarketConcertCard>(find.byType(MarketConcertCard))
          .map((card) => card.concert.title)
          .toList();
      expect(
        titles.indexOf('2027 블랙핑크'),
        lessThan(titles.indexOf('2026 BTS 콘서트')),
      );

      await closeScreen(tester);
    });
  });

  group('매물 목록', () {
    testWidgets('공연을 누르면 그 공연의 매물이 낮은 가격순으로도 보인다', (tester) async {
      await pump(
        tester,
        api: MockResaleApi(latency: Duration.zero, clock: () => _whileOpen),
        home: MarketConcertsScreen(clock: () => _whileOpen),
      );

      await tester.tap(find.text('2026 BIGBANG'));
      await settle(tester);

      expect(find.byType(MarketListingsScreen), findsOneWidget);
      expect(find.byType(ListingRowCard), findsNWidgets(4));
      // 정가와 할인율이 함께 보인다.
      expect(find.text('176,000 MSR'), findsOneWidget);
      expect(find.text(ResaleStrings.discountRate(5)), findsOneWidget);

      await tester.tap(find.text(ResaleStrings.sortLowestPrice));
      await settle(tester);

      final prices = tester
          .widgetList<ListingRowCard>(find.byType(ListingRowCard))
          .map((card) => card.listing.price)
          .toList();
      expect(prices, [150000, 163000, 168000, 176000]);

      await closeScreen(tester);
    });
  });

  group('구매', () {
    testWidgets('매물을 고르면 금액이 보이고, 결제하면 양도 중에서 완료로 바뀐다', (tester) async {
      var now = _whileOpen;
      await pump(
        tester,
        api: MockResaleApi(latency: Duration.zero, clock: () => now),
        home: MarketConcertsScreen(clock: () => now),
      );

      await tester.tap(find.text('2026 BIGBANG'));
      await settle(tester);
      // 기본 정렬(최신등록순)에서 맨 위는 다른 매물이라, 금액으로 짚어 누른다.
      await tester.tap(find.widgetWithText(ListingRowCard, '176,000 MSR'));
      await settle(tester);

      expect(find.byType(ListingPurchaseScreen), findsOneWidget);
      expect(find.text(ResaleStrings.faceValueLabel), findsOneWidget);
      // 정가 186,000 · 등록가 176,000 이라 할인가는 -10,000 이다.
      expect(find.text('-10,000 MSR'), findsOneWidget);
      // 뒤에 남은 매물 목록에도 같은 금액이 있어 이 화면 안에서만 찾는다.
      expect(
        find.descendant(
          of: find.byType(ListingPurchaseScreen),
          matching: find.text('176,000 MSR'),
        ),
        findsOneWidget,
      );
      expect(find.text(ResaleStrings.purchaseWarning), findsOneWidget);

      await tester.tap(find.textContaining(ResaleStrings.purchaseAction));
      await settle(tester);

      expect(find.byType(ListingPurchaseCompleteScreen), findsOneWidget);
      expect(find.text(ResaleStrings.completeTitle), findsOneWidget);
      // 결제가 끝나도 양도는 아직이다.
      expect(find.text(ResaleStrings.transferringBadge), findsOneWidget);

      // 온체인 전송이 끝날 만큼 시간이 지나면 배지가 바뀐다.
      now = now.add(MockResaleApi.confirmAfter);
      await tester.pump(ResaleMetrics.tradePollInterval);
      await settle(tester);

      expect(find.text(ResaleStrings.transferredBadge), findsOneWidget);
      expect(find.text(ResaleStrings.viewTicketLabel), findsOneWidget);

      await closeScreen(tester);
    });
  });

  group('양도 등록', () {
    testWidgets('티켓을 고르고 정가 이하로만 등록할 수 있다', (tester) async {
      final api = MockResaleApi(
        latency: Duration.zero,
        clock: () => _whileOpen,
      );
      await pump(tester, api: api, home: const ListingRegisterScreen());

      expect(find.byType(ListableTicketCard), findsNWidgets(2));

      FilledButton? filledButton(String label) {
        final finder = find.widgetWithText(FilledButton, label);
        return finder.evaluate().isEmpty
            ? null
            : tester.widget<FilledButton>(finder);
      }

      // 고르기 전에는 다음으로 갈 수 없다(꽉 찬 버튼 자체가 없다).
      expect(filledButton(ResaleStrings.registerNext), isNull);

      await tester.tap(find.text('2027 RE:MIND'));
      await settle(tester);
      expect(filledButton(ResaleStrings.registerNext), isNotNull);

      await tester.tap(find.text(ResaleStrings.registerNext));
      await settle(tester);

      // 가격 단계. 고른 티켓 하나만 남고 처음 값은 정가다.
      expect(find.byType(ListableTicketCard), findsOneWidget);
      expect(find.text('198,600'), findsOneWidget);
      expect(find.text(ResaleStrings.priceHint), findsOneWidget);

      await tester.enterText(find.byType(TextField), '200000');
      await settle(tester);

      expect(find.text(ResaleStrings.priceOverFace), findsOneWidget);
      expect(filledButton(ResaleStrings.registerSubmit), isNull);

      await tester.enterText(find.byType(TextField), '176000');
      await settle(tester);

      expect(filledButton(ResaleStrings.registerSubmit), isNotNull);
      await tester.tap(find.text(ResaleStrings.registerSubmit));
      await settle(tester);

      // 등록한 티켓은 목록에서 빠지고, 그 값으로 매물이 생긴다. 다만 마켓
      // 목록에는 다음 날에야 올라가므로 내 거래 내역에서 확인한다. 목의 응답은
      // 타이머를 타므로(fake async) 시간을 조금 흘려야 돌아온다.
      final tickets = api.fetchListableTickets();
      final trades = api.fetchMyTrades();
      final listings = api.fetchListings(4);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await tickets, hasLength(1));
      expect(
        (await trades).where(
          (trade) => trade.isOnSale && trade.price == 176000,
        ),
        hasLength(1),
      );
      expect(
        (await listings).where((listing) => listing.price == 176000),
        isEmpty,
      );

      await closeScreen(tester);
    });

    // 내 티켓 카드의 `양도 등록하기` 로 들어오는 길. 어느 티켓인지 정하고 온
    // 사람에게 다시 고르게 하지 않는다.
    testWidgets('티켓 번호를 받고 들어오면 그 티켓을 골라 둔 채 가격 단계로 간다', (tester) async {
      final api = MockResaleApi(
        latency: Duration.zero,
        clock: () => _whileOpen,
      );
      await pump(
        tester,
        api: api,
        // 목의 등록 가능한 티켓 중 아이유 콘서트(102).
        home: const ListingRegisterScreen(initialTicketId: 102),
      );

      expect(find.byType(ListableTicketCard), findsOneWidget);
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
      // 처음 값은 정가다.
      expect(find.text('165,000'), findsOneWidget);
      expect(find.text(ResaleStrings.registerSubmit), findsOneWidget);

      await closeScreen(tester);
    });

    testWidgets('받은 티켓 번호가 목록에 없으면 고르지 않은 채 고르기부터 한다', (tester) async {
      final api = MockResaleApi(
        latency: Duration.zero,
        clock: () => _whileOpen,
      );
      await pump(
        tester,
        api: api,
        home: const ListingRegisterScreen(initialTicketId: 999),
      );

      expect(find.byType(ListableTicketCard), findsNWidgets(2));
      expect(
        find.widgetWithText(FilledButton, ResaleStrings.registerNext),
        findsNothing,
      );

      await closeScreen(tester);
    });
  });
}

/// 운영 상태와 공연 목록을 몇 번 요청받았는지 세는 껍데기.
///
/// "닫혀 있거나 로그인하지 않았으면 서버를 부르지 않는다" 는 화면에 드러나지
/// 않는 약속이라 이렇게만 확인할 수 있다. 나머지는 그대로 넘긴다.
class _CountingResaleApi implements ResaleApi {
  _CountingResaleApi(this._delegate);

  final ResaleApi _delegate;

  int hoursCalls = 0;
  int concertCalls = 0;

  @override
  Future<MarketHours> fetchMarketHours() {
    hoursCalls++;
    return _delegate.fetchMarketHours();
  }

  @override
  Future<List<MarketConcert>> fetchConcerts() {
    concertCalls++;
    return _delegate.fetchConcerts();
  }

  @override
  Future<List<Listing>> fetchListings(int concertId) =>
      _delegate.fetchListings(concertId);

  @override
  Future<ListingDetail> fetchListing(int listingId) =>
      _delegate.fetchListing(listingId);

  @override
  Future<PurchasedTrade> purchase({
    required int listingId,
    required int expectedPrice,
    required String idempotencyKey,
  }) => _delegate.purchase(
    listingId: listingId,
    expectedPrice: expectedPrice,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TradeStatus> fetchTradeStatus(int tradeId) =>
      _delegate.fetchTradeStatus(tradeId);

  @override
  Future<List<ListableTicket>> fetchListableTickets() =>
      _delegate.fetchListableTickets();

  @override
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  }) => _delegate.createListing(ticketId: ticketId, price: price);

  @override
  Future<List<MyTrade>> fetchMyTrades() => _delegate.fetchMyTrades();

  @override
  Future<void> cancelListing(int listingId) =>
      _delegate.cancelListing(listingId);

  @override
  Future<ListingDetail> updateListingPrice({
    required int listingId,
    required int price,
  }) => _delegate.updateListingPrice(listingId: listingId, price: price);
}
