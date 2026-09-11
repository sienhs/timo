import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/screens/login_screen.dart';
import 'package:timo/features/auth/state/auth_api_scope.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/mypage/screens/my_page_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 서버에 로그아웃을 알렸는지 기록하는 목. 나머지 동작은 [MockAuthApi] 그대로다.
class _RecordingAuthApi extends MockAuthApi {
  _RecordingAuthApi() : super(latency: Duration.zero);

  /// 로그아웃 요청에 실린 리프레시 토큰들. 온 순서대로.
  final loggedOutWith = <String>[];

  @override
  Future<void> logout(String refreshToken) {
    loggedOutWith.add(refreshToken);
    return super.logout(refreshToken);
  }
}

/// 임시 마이페이지의 버튼이 로그인 상태를 따라가는지 본다. 지금 앱에서 로그인
/// 여부를 눈으로 확인할 수 있는 유일한 자리다.
void main() {
  final routes = Map.of(AppRoutes.routes)..remove(AppRoutes.home);

  /// 서버에 닿지 못하는 상황을 흉내 내는 토큰으로 로그인한 상태.
  const offlineTokens = AuthTokens(
    memberId: 1,
    accessToken: 'mock-access-token',
    refreshToken: MockAuthApi.offlineRefreshToken,
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  late _RecordingAuthApi api;

  Future<AuthSession> pumpMyPage(
    WidgetTester tester, {
    required bool loggedIn,
    AuthTokens tokens = MockAuthApi.tokens,
  }) async {
    api = _RecordingAuthApi();
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(tokens);
    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: AuthApiScope(
          api: api,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: MyPageScreen()),
            routes: routes,
          ),
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

  testWidgets('로그인 상태면 로그아웃 버튼이고, 누르면 로그아웃 상태가 되며 서버에도 알린다', (tester) async {
    final session = await pumpMyPage(tester, loggedIn: true);

    expect(find.text(AuthStrings.logout), findsOneWidget);
    expect(find.text(AuthStrings.login), findsNothing);

    await tester.tap(find.text(AuthStrings.logout));
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isFalse);
    // 세션이 바뀌면 화면이 따라 바뀐다.
    expect(find.text(AuthStrings.login), findsOneWidget);
    expect(find.text(AuthStrings.logout), findsNothing);
    // 세션을 비우기 전에 꺼내 둔 리프레시 토큰이 서버로 갔다.
    expect(api.loggedOutWith, [MockAuthApi.tokens.refreshToken]);
  });

  testWidgets('서버에 못 알려도(연결 끊김) 로그아웃 상태가 된다', (tester) async {
    final session = await pumpMyPage(
      tester,
      loggedIn: true,
      tokens: offlineTokens,
    );

    await tester.tap(find.text(AuthStrings.logout));
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isFalse);
    expect(find.text(AuthStrings.login), findsOneWidget);
    // 시도는 했다. 실패를 무시한 것이지 건너뛴 게 아니다.
    expect(api.loggedOutWith, [MockAuthApi.offlineRefreshToken]);
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
