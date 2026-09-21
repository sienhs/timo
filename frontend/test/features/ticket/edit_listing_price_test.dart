import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/resale/constants.dart';
import 'package:timo/features/resale/state/resale_api_scope.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/mock_ticket_api.dart';
import 'package:timo/features/ticket/screens/my_tickets_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';

import 'spy_resale_api.dart';

/// 양도 목록 탭에서 내 매물의 등록가를 고치는 흐름. 등록 취소와 같은 규칙이라
/// 검사도 같은 순서다 — 시트가 무엇을 보여 주는지, 값을 안 바꾸면 보낼 수
/// 없는지, 바꾸면 서버에 가고 카드가 새 값으로 바뀌는지, 서버가 거절하면
/// 그대로인지.
void main() {
  /// 마켓이 닫혀 있는 시각. 가격 수정은 닫힌 시간에만 할 수 있다 — 열려 있는
  /// 동안은 카드에 버튼이 없다(그 경우는 my_tickets_screen_test 가 본다).
  ///
  /// 창이 08:00~23:00 이라 닫혀 있는 시각은 이른 새벽뿐이다.
  DateTime now() => DateTime(2026, 9, 15, 3);

  /// 화면을 띄우고 양도 목록 탭까지 간다. 마켓 목의 판매중인 내 매물은
  /// 2027 RE:MIND 하나(8번, 등록가 132,000 · 정가 143,000)다.
  Future<SpyResaleApi> pumpListings(
    WidgetTester tester, {
    SpyResaleApi? resaleApi,
  }) async {
    final api = resaleApi ?? SpyResaleApi(clock: now);
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: TicketApiScope(
          api: MockTicketApi(latency: Duration.zero, clock: now),
          child: ResaleApiScope(
            api: api,
            child: MaterialApp(home: MyTicketsScreen(clock: now)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(TicketStrings.tabListings));
    await tester.pumpAndSettle();
    return api;
  }

  /// 판매중 카드의 '가격 수정' 을 눌러 시트를 연다.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text(TicketStrings.editPrice));
    await tester.pumpAndSettle();
  }

  FilledButton? submitButton(WidgetTester tester) {
    final finder = find.widgetWithText(
      FilledButton,
      ResaleStrings.editPriceSubmit,
    );
    return finder.evaluate().isEmpty
        ? null
        : tester.widget<FilledButton>(finder);
  }

  group('가격 시트', () {
    testWidgets('지금 등록가를 채워 두고, 그대로면 보낼 수 없다', (tester) async {
      await pumpListings(tester);
      await openSheet(tester);

      // 카드의 버튼도 같은 글자라 시트 안에서만 찾는다.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(ResaleStrings.editPriceTitle),
        ),
        findsOneWidget,
      );
      expect(
        find.text(ResaleStrings.editPriceCurrent('132,000 MSR')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '132,000',
      );
      // 같은 값으로는 보낼 게 없다. 주요 버튼을 비활성으로 유지한다.
      expect(submitButton(tester)!.onPressed, isNull);
    });

    testWidgets('정가를 넘기면 이유를 말하고 보낼 수 없다', (tester) async {
      await pumpListings(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '150000');
      await tester.pumpAndSettle();

      expect(find.text(ResaleStrings.priceOverFace), findsOneWidget);
      expect(submitButton(tester)!.onPressed, isNull);
    });
  });

  group('수정 실행', () {
    testWidgets('새 값을 보내면 서버에 가고 카드가 새 등록가로 바뀐다', (tester) async {
      final api = await pumpListings(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '120000');
      await tester.pumpAndSettle();
      expect(submitButton(tester), isNotNull);

      await tester.tap(find.text(ResaleStrings.editPriceSubmit));
      await tester.pumpAndSettle();

      expect(api.priceUpdates, [(listingId: 8, price: 120000)]);
      expect(
        find.text(TicketStrings.listedPrice('120,000 MSR')),
        findsOneWidget,
      );
      expect(find.text(TicketStrings.priceUpdated), findsOneWidget);
      // 매물은 그대로 팔리는 중이다.
      expect(find.text(TicketStrings.listingBadge), findsOneWidget);
    });

    // 시트가 미리 걸러도 시점 차이로 통과할 수 있다(그새 팔림). 최종 판정은
    // 서버 몫이다.
    testWidgets('서버가 거절하면 그 문구를 띄우고 카드는 그대로다', (tester) async {
      final api = await pumpListings(
        tester,
        resaleApi: SpyResaleApi(
          clock: now,
          priceFailure: const ApiException('이미 팔렸거나 내려간 매물이에요.', status: 409),
        ),
      );
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '120000');
      await tester.pumpAndSettle();
      await tester.tap(find.text(ResaleStrings.editPriceSubmit));
      await tester.pumpAndSettle();

      expect(api.priceUpdates, isEmpty);
      expect(find.text('이미 팔렸거나 내려간 매물이에요.'), findsOneWidget);
      expect(
        find.text(TicketStrings.listedPrice('132,000 MSR')),
        findsOneWidget,
      );
    });
  });
}
