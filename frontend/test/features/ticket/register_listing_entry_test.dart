import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/resale/state/resale_api_scope.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/data/mock_ticket_api.dart';
import 'package:timo/features/ticket/screens/my_tickets_screen.dart';
import 'package:timo/features/ticket/state/ticket_api_scope.dart';
import 'package:timo/routes/app_routes.dart';

import 'spy_resale_api.dart';

/// 예정 공연 카드 더보기에서 양도 등록 화면으로 들어가는 입구.
///
/// 등록 화면 자체는 양도마켓 테스트가 덮는다. 여기서는 그 라우트로 가는지와,
/// 등록하고 돌아왔을 때만 목록을 다시 받는지를 본다. 그래서 등록 화면 자리에
/// 결과만 돌려주는 가짜 화면을 세운다.
void main() {
  DateTime now() => DateTime(2026, 9, 15, 14);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required SpyResaleApi resaleApi,
  }) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: TicketApiScope(
          api: MockTicketApi(latency: Duration.zero, clock: now),
          child: ResaleApiScope(
            api: resaleApi,
            child: MaterialApp(
              home: MyTicketsScreen(clock: now),
              // 화면이 미는 이름이 실제 등록 라우트와 같은지도 이걸로 확인된다.
              routes: {
                AppRoutes.resaleRegister: (_) => const _FakeRegisterScreen(),
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 아이유 카드의 더보기를 연다. 어느 카드든 항목은 같다.
  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
  }

  Future<void> goToRegister(WidgetTester tester) async {
    await openMore(tester);
    await tester.tap(find.text(TicketStrings.registerListing));
    await tester.pumpAndSettle();
  }

  testWidgets('더보기에 양도 등록하기가 예매 취소 위에 있다', (tester) async {
    await pumpScreen(tester, resaleApi: SpyResaleApi(clock: now));
    await openMore(tester);

    final register = find.text(TicketStrings.registerListing);
    final cancel = find.text(TicketStrings.cancelReservation);
    expect(register, findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(
      tester.getCenter(register).dy,
      lessThan(tester.getCenter(cancel).dy),
    );
  });

  testWidgets('양도 등록하기를 누르면 그 티켓 번호를 얹어 등록 화면으로 간다', (tester) async {
    await pumpScreen(tester, resaleApi: SpyResaleApi(clock: now));
    await goToRegister(tester);

    expect(find.byType(_FakeRegisterScreen), findsOneWidget);
    // 아이유 카드의 티켓 번호(예매 목 102). 예매 번호(2)가 아니다 — 등록이
    // 받는 것은 티켓 번호다.
    expect(find.text(_FakeRegisterScreen.argumentLabel(102)), findsOneWidget);
  });

  testWidgets('등록하고 돌아오면 양도 목록을 다시 받는다', (tester) async {
    final api = SpyResaleApi(clock: now);
    await pumpScreen(tester, resaleApi: api);
    expect(api.myTradesCalls, 1);

    await goToRegister(tester);
    await tester.tap(find.text(_FakeRegisterScreen.registered));
    await tester.pumpAndSettle();

    expect(find.byType(MyTicketsScreen), findsOneWidget);
    expect(api.myTradesCalls, 2);
  });

  // 등록 없이 나왔으면 바뀐 게 없다. 다시 받으면 목록이 한 번 깜빡일 뿐이다.
  testWidgets('등록 없이 돌아오면 다시 받지 않는다', (tester) async {
    final api = SpyResaleApi(clock: now);
    await pumpScreen(tester, resaleApi: api);

    await goToRegister(tester);
    await tester.tap(find.text(_FakeRegisterScreen.left));
    await tester.pumpAndSettle();

    expect(find.byType(MyTicketsScreen), findsOneWidget);
    expect(api.myTradesCalls, 1);
  });
}

/// 등록 화면 자리에 세우는 가짜. 실제 화면처럼 등록했으면 true 를, 그냥
/// 나갔으면 아무것도 돌려주지 않는다. 받은 인자(미리 고를 티켓 번호)는 글자로
/// 찍어 검사할 수 있게 한다.
class _FakeRegisterScreen extends StatelessWidget {
  const _FakeRegisterScreen();

  static const registered = '등록 완료';
  static const left = '그냥 나가기';

  static String argumentLabel(Object? argument) => '인자 $argument';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(argumentLabel(ModalRoute.of(context)?.settings.arguments)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(registered),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(left),
          ),
        ],
      ),
    );
  }
}
