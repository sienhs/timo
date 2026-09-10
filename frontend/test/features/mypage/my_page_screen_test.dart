import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/screens/login_screen.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/mypage/screens/my_page_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 임시 마이페이지의 버튼이 로그인 상태를 따라가는지 본다. 지금 앱에서 로그인
/// 여부를 눈으로 확인할 수 있는 유일한 자리다.
void main() {
  final routes = Map.of(AppRoutes.routes)..remove(AppRoutes.home);

  Future<AuthSession> pumpMyPage(
    WidgetTester tester, {
    required bool loggedIn,
  }) async {
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(MockAuthApi.tokens);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: MyPageScreen()),
          routes: routes,
        ),
      ),
    );
    return session;
  }

  testWidgets('로그아웃 상태면 로그인 버튼이고, 누르면 로그인 화면으로 간다', (tester) async {
    await pumpMyPage(tester, loggedIn: false);

    expect(find.text(AuthStrings.login), findsOneWidget);
    expect(find.text(AuthStrings.logout), findsNothing);

    await tester.tap(find.text(AuthStrings.login));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('로그인 상태면 로그아웃 버튼이고, 누르면 로그아웃 상태로 바뀐다', (tester) async {
    final session = await pumpMyPage(tester, loggedIn: true);

    expect(find.text(AuthStrings.logout), findsOneWidget);
    expect(find.text(AuthStrings.login), findsNothing);

    await tester.tap(find.text(AuthStrings.logout));
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isFalse);
    // 세션이 바뀌면 화면이 따라 바뀐다.
    expect(find.text(AuthStrings.login), findsOneWidget);
    expect(find.text(AuthStrings.logout), findsNothing);
  });

  testWidgets('스코프 없이 띄우면 로그아웃 상태로 그린다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: MyPageScreen()),
        routes: routes,
      ),
    );

    expect(find.text(AuthStrings.login), findsOneWidget);
  });
}
