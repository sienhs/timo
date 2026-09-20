import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo_gate/core/theme/app_theme.dart';
import 'package:timo_gate/features/auth/constants.dart';
import 'package:timo_gate/features/auth/data/mock_auth_api.dart';
import 'package:timo_gate/core/storage/device_storage.dart';
import 'package:timo_gate/features/auth/models/auth_tokens.dart';
import 'package:timo_gate/features/auth/state/auth_api_scope.dart';
import 'package:timo_gate/features/auth/state/auth_session.dart';
import 'package:timo_gate/features/auth/state/auth_session_scope.dart';
import 'package:timo_gate/features/auth/widgets/logout_button.dart';

void main() {
  late InMemoryDeviceStorage storage;
  late AuthSession session;
  late _RecordingAuthApi api;

  setUp(() async {
    storage = InMemoryDeviceStorage();
    session = AuthSession(storage: storage);
    api = _RecordingAuthApi();
    await session.signIn(MockAuthApi.adminTokens);
  });

  /// 스캔 화면처럼 AppBar 오른쪽에 버튼을 놓고, 앱처럼 스코프로 감싼다.
  Future<void> pumpButton(WidgetTester tester) => tester.pumpWidget(
    AuthSessionScope(
      session: session,
      child: AuthApiScope(
        api: api,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(appBar: AppBar(actions: const [LogoutButton()])),
        ),
      ),
    ),
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip(AuthStrings.logout));
    await tester.pumpAndSettle();
  }

  testWidgets('누르면 확인 팝업이 뜨고 아직 로그아웃되지 않는다', (tester) async {
    await pumpButton(tester);
    await openDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(AuthStrings.logoutConfirmTitle), findsOneWidget);
    expect(find.text(AuthStrings.logoutConfirmBody), findsOneWidget);
    expect(session.isLoggedIn, isTrue);
  });

  testWidgets('취소하면 팝업만 닫히고 로그인 상태가 유지된다', (tester) async {
    await pumpButton(tester);
    await openDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, AuthStrings.cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(session.isLoggedIn, isTrue);
    expect(api.loggedOut, isEmpty);
  });

  testWidgets('확인하면 기기 토큰을 지우고 서버에도 알린다', (tester) async {
    await pumpButton(tester);
    await openDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, AuthStrings.logout));
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isFalse);
    expect(storage.values, isEmpty);
    expect(api.loggedOut, [MockAuthApi.adminTokens.refreshToken]);
  });

  testWidgets('서버에 못 알려도 로그아웃은 된다', (tester) async {
    // 목은 이 토큰으로 로그아웃하면 연결 오류를 던진다.
    await session.signIn(
      const AuthTokens(
        memberId: 1,
        accessToken: 'access',
        refreshToken: MockAuthApi.offlineRefreshToken,
        accessTokenExpiresIn: Duration(minutes: 30),
      ),
    );
    await pumpButton(tester);
    await openDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, AuthStrings.logout));
    await tester.pumpAndSettle();

    expect(session.isLoggedIn, isFalse);
    expect(tester.takeException(), isNull);
  });
}

/// 로그아웃 요청에 실린 리프레시 토큰을 기록하는 목.
class _RecordingAuthApi extends MockAuthApi {
  _RecordingAuthApi() : super(latency: Duration.zero);

  final loggedOut = <String>[];

  @override
  Future<void> logout(String refreshToken) async {
    loggedOut.add(refreshToken);
    await super.logout(refreshToken);
  }
}
