import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/widgets/error_snack_bar.dart';
import 'package:timo/features/auth/constants.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/models/auth_tokens.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/favorite/data/mock_favorite_api.dart';
import 'package:timo/features/notification/data/mock_notification_api.dart';
import 'package:timo/features/notification/screens/notification_screen.dart';
import 'package:timo/features/settings/constants.dart';
import 'package:timo/routes/app_routes.dart';

/// 환경 설정 화면. 무엇이 보이는가와 누르면 어디로 가는가만 본다. 픽셀 값은
/// 굳히지 않는다.
void main() {
  /// 로그인 상태를 만드는 토큰.
  const tokens = AuthTokens(
    memberId: 1,
    accessToken: 'test-access-token',
    refreshToken: 'test-refresh-token',
    accessTokenExpiresIn: Duration(minutes: 30),
  );

  /// 360 x 800 dp
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpSettings(WidgetTester tester, {bool loggedIn = true}) async {
    usePhoneSize(tester);
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(tokens);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      App(
        initialRoute: AppRoutes.settings,
        session: session,
        // 알림함을 누르면 알림함 화면이 열린다. 목을 안 꽂으면 진짜 서버로 간다.
        notificationApi: MockNotificationApi(latency: Duration.zero),
        // 로그인 상태면 앱이 찜 목록을 받아 온다. 목을 안 꽂으면 진짜 서버로 간다.
        favoriteApi: MockFavoriteApi(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 아래쪽 줄은 화면 밖에 있을 수 있다. 굴려서 보이게 한 뒤 누른다.
  Future<void> tapTile(WidgetTester tester, String label) async {
    final tile = find.text(label);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
  }

  testWidgets('로그인 상태면 계정 · 알림 · 앱 정보 묶음이 다 보인다', (tester) async {
    await pumpSettings(tester);

    expect(find.text(SettingsStrings.title), findsOneWidget);
    for (final label in [
      SettingsStrings.accountSection,
      SettingsStrings.editProfile,
      SettingsStrings.changePassword,
      SettingsStrings.deleteAccount,
      SettingsStrings.notificationSection,
      SettingsStrings.pushToggle,
      SettingsStrings.inbox,
      SettingsStrings.infoSection,
      SettingsStrings.version,
      SettingsStrings.appVersion,
      SettingsStrings.terms,
      SettingsStrings.privacy,
      SettingsStrings.licenses,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text(AuthStrings.login), findsNothing);
  });

  testWidgets('로그인 안 했으면 계정 항목 대신 로그인 입구가 보인다', (tester) async {
    await pumpSettings(tester, loggedIn: false);

    expect(find.text(SettingsStrings.accountSection), findsOneWidget);
    expect(find.text(SettingsStrings.loginPrompt), findsOneWidget);
    expect(find.text(AuthStrings.login), findsOneWidget);
    expect(find.text(SettingsStrings.editProfile), findsNothing);
    // 계정 말고 다른 묶음은 그대로다.
    expect(find.text(SettingsStrings.pushToggle), findsOneWidget);
    expect(find.text(SettingsStrings.licenses), findsOneWidget);
  });

  testWidgets('알림함을 누르면 알림함 화면으로 간다', (tester) async {
    await pumpSettings(tester);

    await tapTile(tester, SettingsStrings.inbox);
    // 알림함은 목록 끝의 동그라미가 계속 돌아 pumpAndSettle 을 쓸 수 없다.
    // 화면 전환이 끝날 만큼만 기다린다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NotificationScreen), findsOneWidget);
  });

  testWidgets('푸시 알림 스위치는 줄을 눌러도 꺼진다', (tester) async {
    await pumpSettings(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tapTile(tester, SettingsStrings.pushToggle);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('오픈소스 라이선스를 누르면 라이선스 화면이 열린다', (tester) async {
    await pumpSettings(tester);

    await tapTile(tester, SettingsStrings.licenses);
    // 라이선스 목록을 모으는 동안 동그라미가 돌아 pumpAndSettle 을 쓸 수 없다.
    // 화면 전환이 끝날 만큼만 기다린다.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('화면이 없는 항목을 누르면 준비 중 안내가 뜬다', (tester) async {
    await pumpSettings(tester);

    await tapTile(tester, SettingsStrings.changePassword);
    await tester.pump();

    expect(
      find.text(
        toastText(SettingsStrings.notReady(SettingsStrings.changePassword)),
      ),
      findsOneWidget,
    );
    expect(find.byType(NotificationScreen), findsNothing);
  });

  /// 이 안내는 한때 셸에서 검정 기본 스낵바로 떴다. 앱의 다른 안내와 생김새가
  /// 달라 같은 앱으로 보이지 않았다. 빠른 메뉴 항목에 화면이 다 생겨 그 자리를
  /// 이 화면이 이어받는다 — 공통 상자로 돌아가지 않게 굳혀 둔다.
  testWidgets('준비 중 안내는 앱 공통 상자로 뜬다', (tester) async {
    await pumpSettings(tester);

    await tapTile(tester, SettingsStrings.terms);
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    // 공통 상자는 SnackBar 를 비워 두고 안쪽 Container 가 모양을 그린다.
    expect(snackBar.backgroundColor, Colors.transparent);
    expect(snackBar.clipBehavior, Clip.none);
  });
}
