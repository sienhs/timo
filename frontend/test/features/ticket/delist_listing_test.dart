import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/resale/data/mock_resale_api.dart';
import 'package:timo/features/resale/data/resale_api.dart';
import 'package:timo/features/resale/state/resale_api_scope.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/mock_ticket_api.dart';
import 'package:timo/features/ticket/screens/my_tickets_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';
import 'package:timo/features/ticket/widgets/listing_card.dart';

import 'spy_resale_api.dart';

/// 양도 목록 탭에서 내 매물을 내리는 흐름. 예매 취소와 같은 규칙이라 검사도
/// 같은 순서다 — 팝업이 무엇을 보여 주는지, 그대로 두면 아무 일도 없는지,
/// 내리면 서버에 가고 결과가 카드로 남는지, 서버가 거절하면 그대로인지.
void main() {
  DateTime now() => DateTime(2026, 9, 15, 14);

  /// 화면을 띄우고 양도 목록 탭까지 간다. 예매 목은 시안 데이터 그대로이고,
  /// 마켓 목은 판매중인 내 매물 하나(2027 RE:MIND)와 팔린 것 하나다.
  Future<void> pumpListings(WidgetTester tester, {ResaleApi? resaleApi}) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: TicketApiScope(
          api: MockTicketApi(latency: Duration.zero, clock: now),
          child: ResaleApiScope(
            api: resaleApi ?? MockResaleApi(latency: Duration.zero, clock: now),
            child: MaterialApp(home: MyTicketsScreen(clock: now)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(TicketStrings.tabListings));
    await tester.pumpAndSettle();
  }

  /// 판매중 카드의 '등록 취소' 를 눌러 팝업을 연다.
  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text(TicketStrings.delist));
    await tester.pumpAndSettle();
  }

  group('확인 팝업', () {
    testWidgets('무엇을 내리는지와 등록가를 보여준다', (tester) async {
      await pumpListings(tester);
      await openDialog(tester);

      // 공연명·좌석은 뒤에 깔린 카드에도 있으므로 팝업 안에서만 찾는다.
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(text));

      expect(find.text(TicketStrings.delistConfirmTitle), findsOneWidget);
      expect(inDialog('2027 RE:MIND'), findsOneWidget);
      expect(inDialog('R구역 11열 2번'), findsOneWidget);
      expect(
        inDialog(TicketStrings.listedPriceLabel('132,000 MSR')),
        findsOneWidget,
      );
      expect(find.text(TicketStrings.delistConfirmAgree), findsOneWidget);
      expect(find.text(TicketStrings.cancelConfirmKeep), findsOneWidget);
    });

    testWidgets('그대로 두면 아무 일도 안 일어난다', (tester) async {
      final api = SpyResaleApi(clock: now);
      await pumpListings(tester, resaleApi: api);
      await openDialog(tester);

      await tester.tap(find.text(TicketStrings.cancelConfirmKeep));
      await tester.pumpAndSettle();

      expect(api.cancelled, isEmpty);
      expect(find.text(TicketStrings.listingBadge), findsOneWidget);
    });
  });

  group('취소 실행', () {
    testWidgets('내리면 서버에 보내고 회색 카드로 남는다', (tester) async {
      final api = SpyResaleApi(clock: now);
      await pumpListings(tester, resaleApi: api);
      await openDialog(tester);

      await tester.tap(find.text(TicketStrings.delistConfirmAgree));
      await tester.pumpAndSettle();

      // 목의 판매중 내 매물은 8번이다.
      expect(api.cancelled, [8]);
      // 목록에서 지우지 않는다. 결과를 눈으로 봐야 한다.
      expect(find.byType(ListingCard), findsNWidgets(2));
      expect(find.text(TicketStrings.delistedNotice), findsOneWidget);
      expect(find.text(TicketStrings.listingBadge), findsNothing);
      // 올라가 있는 매물이 없으니 탭 옆 숫자는 0 이다.
      expect(find.text('${TicketStrings.tabListings} 0'), findsOneWidget);
    });

    // 팝업도 여는 데 한 프레임이 걸린다. 두 장이 겹치면 확인을 두 번 받게 되고
    // 취소 요청도 두 번 나간다.
    testWidgets('빨리 두 번 눌러도 팝업은 한 장이고 요청도 한 번이다', (tester) async {
      final api = SpyResaleApi(clock: now);
      await pumpListings(tester, resaleApi: api);

      await tester.tap(find.text(TicketStrings.delist));
      await tester.tap(find.text(TicketStrings.delist));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.text(TicketStrings.delistConfirmAgree));
      await tester.pumpAndSettle();

      expect(api.cancelled, [8]);
      expect(find.byType(Dialog), findsNothing);
    });

    // 화면이 미리 걸러도 시점 차이로 통과할 수 있다. 최종 판정은 서버 몫이다.
    testWidgets('서버가 거절하면 그 문구를 띄우고 목록은 그대로다', (tester) async {
      final api = SpyResaleApi(
        clock: now,
        cancelFailure: const ApiException('이미 팔렸거나 내려간 매물이에요.', status: 409),
      );
      await pumpListings(tester, resaleApi: api);
      await openDialog(tester);

      await tester.tap(find.text(TicketStrings.delistConfirmAgree));
      await tester.pumpAndSettle();

      expect(find.text(toastText('이미 팔렸거나 내려간 매물이에요.')), findsOneWidget);
      expect(find.text(TicketStrings.listingBadge), findsOneWidget);
      expect(find.text(TicketStrings.delistedNotice), findsNothing);
    });
  });
}
