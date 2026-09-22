import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/utils/formatters.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/resale/constants.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/data/resale_api.dart';
import 'package:timo/features/resale/models/my_trade.dart';
import 'package:timo/features/resale/state/resale_api_scope.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/mock_ticket_api.dart';
import 'package:timo/features/ticket/data/ticket_api.dart';
import 'package:timo/features/ticket/models/entry_pass.dart';
import 'package:timo/features/ticket/models/my_ticket.dart';
import 'package:timo/features/ticket/models/reservation_detail.dart';
import 'package:timo/features/ticket/screens/my_tickets_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';
import 'package:timo/features/ticket/widgets/listing_card.dart';
import 'package:timo/features/ticket/widgets/past_ticket_card.dart';
import 'package:timo/features/ticket/widgets/ticket_list_skeleton.dart';
import 'package:timo/features/ticket/widgets/ticket_tab_bar.dart';
import 'package:timo/features/ticket/widgets/upcoming_ticket_card.dart';

import 'spy_resale_api.dart';

void main() {
  /// 테스트가 보는 '지금'. 언제 돌려도 결과가 같아야 해서 고정한다.
  ///
  /// 자정에서 먼 시각인 것이 중요하다. 목 데이터의 첫 티켓은 '1시간 뒤'
  /// 공연인데, 실제 시계를 쓰면 밤 11시 이후에 그 공연이 자정을 넘어
  /// **내일**이 되어 D-day 배지가 `D-DAY` 대신 `D-1` 로 찍힌다.
  ///
  /// 그리고 마켓이 **닫혀 있는** 시각이다. 가격 수정은 닫힌 시간에만 되므로,
  /// 열려 있는 경우를 보는 테스트만 제 시각을 따로 넣는다. 창이 08:00~23:00
  /// 이라 닫혀 있는 시각은 이른 새벽뿐이다.
  DateTime now() => DateTime(2026, 9, 15, 3);

  /// 화면을 목과 함께 띄운다. 지연은 0 이라 한 번 더 pump 하면 목록이 나온다.
  ///
  /// 화면과 목이 **같은 시각**을 봐야 한다. 한쪽만 고정하면 목이 만든 날짜와
  /// 화면이 재는 기준이 어긋나 배지가 다시 흔들린다.
  ///
  /// 화면이 로그인 세션을 보고 목록을 부르므로 기본은 로그인 상태다. 충전 화면
  /// 테스트와 같은 방식으로 세션을 만든다.
  ///
  /// 양도 목록 탭은 마켓 목을 본다. 시안 데이터는 판매중인 내 매물 하나와 팔린
  /// 내 매물 하나다. 예매 목과 시나리오를 따로 받아, 한쪽만 실패하는 경우를 본다.
  Future<void> pumpScreen(
    WidgetTester tester, {
    TicketApi? api,
    TicketMockScenario scenario = TicketMockScenario.design,
    ResaleApi? resaleApi,
    ResaleMockScenario resaleScenario = ResaleMockScenario.design,
    bool loggedIn = true,
  }) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: TicketApiScope(
          api:
              api ??
              MockTicketApi(
                latency: Duration.zero,
                scenario: scenario,
                clock: now,
              ),
          child: ResaleApiScope(
            api:
                resaleApi ??
                MockResaleApi(
                  latency: Duration.zero,
                  scenario: resaleScenario,
                  clock: now,
                ),
            child: MaterialApp(home: MyTicketsScreen(clock: now)),
          ),
        ),
      ),
    );
  }

  group('로그인', () {
    // 서버가 로그인한 회원의 주문만 주므로 비로그인으로 부르면 401 뿐이다.
    // 부르지 않고 안내를 낸다. 목을 '실패' 시나리오로 두어, 만약 불렀다면 오류
    // 문구가 떠서 들키게 한다.
    testWidgets('비로그인이면 목록을 부르지 않고 로그인 안내를 낸다', (tester) async {
      await pumpScreen(
        tester,
        scenario: TicketMockScenario.error,
        loggedIn: false,
      );
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.loginPrompt), findsOneWidget);
      expect(find.text(AuthStrings.login), findsOneWidget);
      expect(find.byType(TicketTabBar), findsNothing);
      expect(find.text('인터넷 연결을 확인해주세요.'), findsNothing);
    });
  });

  group('탭과 목록', () {
    testWidgets('예정 탭이 먼저 열리고 예정 공연만 나온다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // 시안 데이터는 예정 2장 · 지난 2장이다.
      expect(find.byType(UpcomingTicketCard), findsNWidgets(2));
      expect(find.byType(PastTicketCard), findsNothing);
      expect(find.text('2026 REMIND: 리센느'), findsOneWidget);
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    });

    testWidgets('탭 옆에 개수가 붙는다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('${TicketStrings.tabUpcoming} 2'), findsOneWidget);
      expect(find.text('${TicketStrings.tabPast} 2'), findsOneWidget);
    });

    testWidgets('지난 공연 탭을 누르면 지난 공연만 나온다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('${TicketStrings.tabPast} 2'));
      await tester.pumpAndSettle();

      expect(find.byType(PastTicketCard), findsNWidgets(2));
      expect(find.byType(UpcomingTicketCard), findsNothing);
      expect(find.text('2025 블랙핑크'), findsOneWidget);
    });
  });

  group('양도 목록 탭', () {
    /// 양도 목록 탭으로 간다. 이름 옆 숫자가 시나리오마다 달라 이름으로 찾는다.
    Future<void> openListings(WidgetTester tester) async {
      await tester.tap(find.textContaining(TicketStrings.tabListings));
      await tester.pumpAndSettle();
    }

    // 마켓 목의 시안 데이터는 판매중인 내 매물 하나와 팔린 내 매물 하나다.
    testWidgets('판매중인 매물 수만 붙고, 팔린 매물도 카드로 남는다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text('${TicketStrings.tabListings} 1'), findsOneWidget);
      await openListings(tester);

      expect(find.byType(ListingCard), findsNWidgets(2));
      expect(find.text(TicketStrings.listingBadge), findsOneWidget);
      expect(find.text(TicketStrings.soldBadge), findsOneWidget);
      expect(find.text(TicketStrings.soldNotice), findsOneWidget);
      // 버튼은 판매중 카드에만 있다.
      expect(find.text(TicketStrings.editPrice), findsOneWidget);
      expect(find.text(TicketStrings.delist), findsOneWidget);
      expect(find.byType(UpcomingTicketCard), findsNothing);
      expect(find.byType(PastTicketCard), findsNothing);
    });

    testWidgets('등록가는 코인 단위로, 하루 넘게 남은 마감은 일시로 찍힌다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await openListings(tester);

      expect(
        find.text(TicketStrings.listedPrice(formatMsr(132000))),
        findsOneWidget,
      );
      // 목의 판매중 매물은 96일 뒤 공연이다.
      expect(
        find.text(TicketStrings.deadlineAt('2026.12.20 03:00')),
        findsOneWidget,
      );
    });

    // 수정 흐름 자체는 edit_listing_price_test 가 본다. 여기서는 입구만.
    testWidgets('가격 수정을 누르면 가격 시트가 열린다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();
      await openListings(tester);

      await tester.tap(find.text(TicketStrings.editPrice));
      await tester.pumpAndSettle();

      expect(find.text(ResaleStrings.editPriceSubmit), findsOneWidget);
    });

    // 매물은 등록 즉시 마켓에 올라간다. 방금 올린 매물도 어제 올린 매물과
    // 똑같이 판매중이다 — 따로 대기 상태를 두지 않는다.
    testWidgets('오늘 올린 매물도 어제 올린 매물과 같이 판매중이다', (tester) async {
      // 목의 시안 매물은 어제 것이라, 오늘(9월 15일) 올린 매물을 하나 더 만든다.
      final resaleApi = MockResaleApi(latency: Duration.zero, clock: now);
      // 목의 응답은 타이머를 타므로(fake async) 시간을 조금 흘려야 돌아온다.
      final listed = resaleApi.createListing(ticketId: 101, price: 190000);
      await tester.pump(const Duration(milliseconds: 1));
      await listed;

      await pumpScreen(tester, resaleApi: resaleApi);
      await tester.pumpAndSettle();
      await openListings(tester);

      expect(find.text(TicketStrings.listingBadge), findsNWidgets(2));
      expect(find.text(TicketStrings.delist), findsNWidgets(2));
    });

    // 마켓이 열려 있는 동안은 거래 중 가격이 고정이라 서버가 수정을 거절한다.
    // 눌러서 거절당하게 두지 않고 버튼을 안 낸다. 등록 취소는 그대로다.
    testWidgets('마켓이 열려 있으면 가격 수정 버튼이 없고 등록 취소만 남는다', (tester) async {
      await pumpScreen(
        tester,
        resaleApi: MockResaleApi(
          latency: Duration.zero,
          clock: () => DateTime(2026, 9, 15, 21),
        ),
      );
      await tester.pumpAndSettle();
      await openListings(tester);

      expect(find.text(TicketStrings.listingBadge), findsOneWidget);
      expect(find.text(TicketStrings.editPrice), findsNothing);
      expect(find.text(TicketStrings.delist), findsOneWidget);
    });

    testWidgets('올린 매물이 없으면 0 과 빈 안내가 나온다', (tester) async {
      await pumpScreen(tester, resaleScenario: ResaleMockScenario.empty);
      await tester.pumpAndSettle();

      expect(find.text('${TicketStrings.tabListings} 0'), findsOneWidget);
      await openListings(tester);

      expect(find.text(TicketStrings.emptyListings), findsOneWidget);
    });

    // 마켓과 예매는 다른 조회다. 마켓이 안 돼도 내 티켓은 보여야 한다.
    testWidgets('마켓이 실패해도 예정 공연은 보이고, 양도 탭만 다시 시도를 낸다', (tester) async {
      await pumpScreen(tester, resaleScenario: ResaleMockScenario.error);
      await tester.pumpAndSettle();

      expect(find.byType(UpcomingTicketCard), findsNWidgets(2));
      // 세어 본 게 없으니 숫자가 없다.
      expect(find.text(TicketStrings.tabListings), findsOneWidget);
      await openListings(tester);

      expect(find.text('양도마켓을 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });

  group('예정 카드의 버튼', () {
    // 시안에서 카드마다 버튼이 다른 이유다. 공연 시간대에 들어온 티켓만 QR 이 열린다.
    testWidgets('공연이 곧 시작하면 입장 QR, 아니면 상세정보', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.enterQr), findsOneWidget);
      expect(find.text(TicketStrings.showDetail), findsOneWidget);
      // QR 이 안 열린 카드에는 그 이유가 한 줄 붙는다.
      expect(find.text(TicketStrings.qrOpensBeforeShow), findsOneWidget);
    });

    testWidgets('D-day 배지가 남은 날만큼 찍힌다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      // 목의 두 티켓은 각각 오늘과 9일 뒤다.
      expect(find.text('D-DAY'), findsOneWidget);
      expect(find.text('D-9'), findsOneWidget);
    });
  });

  group('티켓 상태별 카드', () {
    /// 상태 시나리오는 카드가 여덟 장이라 기본 화면 높이(600)에 다 안 그려진다.
    /// 목록이 보이는 것만 만들기 때문이다. 화면을 길게 늘여 전부 그리게 한다.
    Future<void> pumpStates(WidgetTester tester, {ResaleApi? resaleApi}) async {
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpScreen(
        tester,
        scenario: TicketMockScenario.states,
        resaleApi: resaleApi,
      );
      await tester.pumpAndSettle();
    }

    bool tileEnabled(WidgetTester tester, String label) =>
        tester.widget<ListTile>(find.widgetWithText(ListTile, label)).enabled;

    // 시안에 없는 카드들. 서버가 티켓 상태를 주므로, 눌러 보고 거절당하게
    // 하지 않고 카드에 사정을 적는다.
    testWidgets('상태마다 버튼 대신 다른 안내가 나온다', (tester) async {
      await pumpStates(tester);

      expect(find.text(TicketStrings.listedNotice), findsOneWidget);
      expect(find.text(TicketStrings.issuingNotice), findsOneWidget);
      expect(find.text(TicketStrings.mintFailedNotice), findsOneWidget);
      expect(find.text(TicketStrings.refundedNotice), findsOneWidget);
      expect(find.text(TicketStrings.cancelledNotice), findsOneWidget);
      expect(find.text(TicketStrings.usedNotice), findsOneWidget);
      expect(find.text(TicketStrings.unknownStatusNotice), findsOneWidget);

      // 버튼은 양도로 받은 보유 티켓 한 장에만 있다. 입장 완료 티켓은 오늘
      // 공연이지만 QR 이 열리지 않는다 — 서버가 거절하는 상태다.
      expect(find.text(TicketStrings.showDetail), findsOneWidget);
      expect(find.text(TicketStrings.enterQr), findsNothing);
    });

    // 아직 표가 없는데 남은 날을 세는 게 앞서 나간다.
    testWidgets('발행 중 카드는 D-day 대신 NFT 발행 중 배지를 단다', (tester) async {
      await pumpStates(tester);

      expect(find.text(TicketStrings.issuingBadge), findsOneWidget);
      expect(find.text('D-3'), findsNothing);
    });

    // 남은 날을 세는 게 의미가 없다. 이미 못 가는 공연이다.
    testWidgets('회수·환불된 티켓에는 D-day 배지가 없다', (tester) async {
      await pumpStates(tester);

      expect(find.text('D-9'), findsNothing);
    });

    // 회수된 티켓은 예정 탭에 남는다. 지난 공연 탭에 섞이면 다녀온 공연으로 읽힌다.
    testWidgets('회수·환불된 티켓은 지난 공연 탭에 안 간다', (tester) async {
      await pumpStates(tester);

      expect(find.text('${TicketStrings.tabUpcoming} 8'), findsOneWidget);
      expect(find.text('${TicketStrings.tabPast} 0'), findsOneWidget);
    });

    // 발행 중·입장 완료·회수·환불·모르는 상태는 할 수 있는 일이 없다.
    testWidgets('더보기는 손에 있는 티켓(보유·양도 등록 중)에만 붙는다', (tester) async {
      await pumpStates(tester);

      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });

    // 등록 중인 티켓의 위 자리는 등록이 아니라 취소다. 올라가 있는 티켓에
    // `양도 등록하기` 를 잠긴 채로 두면 할 수 있는 일이 하나도 없게 된다.
    testWidgets('양도 등록 중이면 등록 자리가 등록 취소로 바뀐다', (tester) async {
      await pumpStates(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.cancelListing), findsOneWidget);
      expect(find.text(TicketStrings.registerListing), findsNothing);
      // 예매 취소는 그대로 잠긴다. 먼저 내려야 한다.
      expect(tileEnabled(tester, TicketStrings.cancelReservation), isFalse);
      expect(find.text(TicketStrings.cancelWhileListed), findsOneWidget);
    });

    // 좌석으로 매물을 맞춰 찾는데 맞는 것이 없다. 예매 목과 마켓 목의 시안
    // 데이터는 서로 다른 공연이라 이 시나리오에서는 늘 없다.
    testWidgets('매물을 못 찾으면 등록 취소가 잠기고 양도 목록 탭으로 보낸다', (tester) async {
      await pumpStates(tester);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(tileEnabled(tester, TicketStrings.cancelListing), isFalse);
      expect(find.text(TicketStrings.cancelListingUnknown), findsOneWidget);
    });

    // 맞는 매물이 있으면 양도 목록 탭까지 가지 않고 여기서 내린다. 팝업과
    // 취소 요청은 그 탭의 `등록 취소` 와 같은 것을 쓴다.
    testWidgets('매물을 찾으면 여기서 바로 내리고 그 매물 번호가 나간다', (tester) async {
      // 목의 등록 중 티켓과 같은 좌석(공연 11, R석 12열 24번)이어야 맞는다.
      final api = SpyResaleApi(
        clock: now,
        extraTrades: [
          MyTrade(
            type: MyTradeType.sale,
            listingId: 777,
            status: MyTradeStatus.listed,
            concertId: 11,
            concertTitle: '2026 REMIND: 리센느',
            venueName: '올림픽공원 체조경기장',
            sectionName: 'R석',
            seatRow: 12,
            seatNumber: 24,
            price: 140000,
            faceValue: 154000,
            occurredAt: now(),
          ),
        ],
      );
      await pumpStates(tester, resaleApi: api);

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(tileEnabled(tester, TicketStrings.cancelListing), isTrue);

      await tester.tap(find.text(TicketStrings.cancelListing));
      await tester.pumpAndSettle();
      // 양도 목록 탭과 같은 확인 팝업이다.
      expect(find.text(TicketStrings.delistConfirmTitle), findsOneWidget);

      await tester.tap(find.text(TicketStrings.delistConfirmAgree));
      await tester.pumpAndSettle();

      expect(api.cancelled, [777]);
    });

    // 예매 행이 판 사람 것이라 취소는 404 다. 다시 파는 것은 된다.
    testWidgets('양도로 받은 티켓은 등록은 되고 예매 취소만 잠긴다', (tester) async {
      await pumpStates(tester);

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      expect(tileEnabled(tester, TicketStrings.registerListing), isTrue);
      expect(tileEnabled(tester, TicketStrings.cancelReservation), isFalse);
      expect(find.text(TicketStrings.cancelNotBooked), findsOneWidget);
    });
  });

  group('빈 목록과 실패', () {
    testWidgets('탭마다 다른 빈 상태 문구가 나온다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.empty);
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.emptyUpcoming), findsOneWidget);
      expect(find.text(TicketStrings.emptyUpcomingAction), findsOneWidget);

      await tester.tap(find.text('${TicketStrings.tabPast} 0'));
      await tester.pumpAndSettle();
      expect(find.text(TicketStrings.emptyPast), findsOneWidget);
    });

    testWidgets('불러오는 동안 뼈대 카드를 세운다', (tester) async {
      await pumpScreen(
        tester,
        api: MockTicketApi(
          latency: const Duration(milliseconds: 100),
          clock: now,
        ),
      );
      await tester.pump();

      expect(find.byType(TicketListSkeleton), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(TicketListSkeleton), findsNothing);
    });

    testWidgets('실패하면 문구와 다시 시도가 나온다', (tester) async {
      await pumpScreen(tester, scenario: TicketMockScenario.error);
      await tester.pumpAndSettle();

      expect(find.text('인터넷 연결을 확인해주세요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });
  });

  group('검색', () {
    // 티켓이 적으면 두 줄을 눈으로 훑는 편이 빠르다. 시안은 2장짜리 목록 위에도 검색을 뒀다.
    testWidgets('티켓이 적으면 검색 칸을 안 낸다', (tester) async {
      await pumpScreen(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('많아지면 검색 칸이 나오고 제목으로 걸러진다', (tester) async {
      await pumpScreen(tester, api: _ManyTicketsApi(now));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '아이유');
      await tester.pumpAndSettle();

      expect(find.byType(UpcomingTicketCard), findsOneWidget);
      expect(find.text('2026 아이유 콘서트'), findsOneWidget);
    });

    testWidgets('걸러서 비면 찾는 게 없다고 알린다', (tester) async {
      await pumpScreen(tester, api: _ManyTicketsApi(now));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '없는공연');
      await tester.pumpAndSettle();

      expect(find.text(TicketStrings.searchEmpty('없는공연')), findsOneWidget);
      expect(find.text(TicketStrings.emptyUpcoming), findsNothing);
    });
  });
}

/// 검색 칸이 나올 만큼(5장 이상) 예정 티켓을 주는 목.
///
/// 시나리오로 만들지 않은 이유: 검색 칸이 뜨는 경계를 보려고 만든 데이터라
/// 앱에서 골라 볼 일이 없다. `MockTicketApi` 에 두면 실행 인자만 늘어난다.
class _ManyTicketsApi implements TicketApi {
  /// 화면과 같은 시계를 받아야 한다. 여기서 진짜 시계를 쓰면 목이 만든 공연
  /// 날짜와 화면이 재는 기준이 갈려, 예정 공연이 지난 공연으로 넘어가 버린다.
  _ManyTicketsApi(DateTime Function() clock)
    : _base = MockTicketApi(latency: Duration.zero, clock: clock);

  final MockTicketApi _base;

  @override
  Future<List<MyTicket>> fetchMyTickets() async {
    final tickets = await _base.fetchMyTickets();
    final upcoming = tickets.take(2).toList();
    return [...upcoming, for (var i = 0; i < 4; i++) upcoming.first.copyWith()];
  }

  @override
  Future<void> cancelReservation(int reservationId) =>
      _base.cancelReservation(reservationId);

  @override
  Future<ReservationDetail> createReservation({
    required int concertId,
    required int seatId,
  }) => _base.createReservation(concertId: concertId, seatId: seatId);

  @override
  Future<ReservationDetail> fetchReservation(int reservationId) =>
      _base.fetchReservation(reservationId);

  @override
  Future<EntryPass> issueEntryPass(int ticketId) =>
      _base.issueEntryPass(ticketId);
}
