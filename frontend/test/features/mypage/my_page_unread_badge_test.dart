import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/auth/data/mock_auth_api.dart';
import 'package:timo/features/auth/data/token_storage.dart';
import 'package:timo/features/auth/state/auth_session.dart';
import 'package:timo/features/auth/state/auth_session_scope.dart';
import 'package:timo/features/mypage/data/mock_my_page_api.dart';
import 'package:timo/features/mypage/screens/my_page_screen.dart';
import 'package:timo/features/mypage/state/my_page_api_scope.dart';
import 'package:timo/features/mypage/widgets/my_page_top_bar.dart';
import 'package:timo/features/notification/constants.dart';
import 'package:timo/features/notification/data/mock_notification_api.dart';
import 'package:timo/features/notification/notification_destination.dart';
import 'package:timo/features/notification/push_notification_scope.dart';
import 'package:timo/features/notification/push_notification_service.dart';
import 'package:timo/features/notification/state/notification_api_scope.dart';
import 'package:timo/routes/app_routes.dart';

/// 마이페이지 종 위의 안 읽음 점. 화면에 들어올 때와 알림함에서 돌아왔을 때만
/// 개수를 묻는다. 그 두 시점이 맞는지를 본다.
void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// 종에 점이 찍혀 있는지.
  bool hasDot(WidgetTester tester) => tester
      .widget<MyPageTopBar>(find.byType(MyPageTopBar))
      .hasUnreadNotifications;

  Future<void> pumpMyPage(
    WidgetTester tester, {
    required bool loggedIn,
    MockNotificationScenario scenario = MockNotificationScenario.normal,
    bool withNotificationScope = true,
    PushNotifications? push,
  }) async {
    usePhoneSize(tester);
    final session = AuthSession(storage: InMemoryTokenStorage());
    if (loggedIn) await session.signIn(MockAuthApi.tokens);
    addTearDown(session.dispose);

    final api = MockNotificationApi(latency: Duration.zero, scenario: scenario);
    final Widget app = MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: MyPageScreen()),
      routes: Map.of(AppRoutes.routes)..remove(AppRoutes.home),
    );

    await tester.pumpWidget(
      AuthSessionScope(
        session: session,
        child: MyPageApiScope(
          api: const MockMyPageApi(latency: Duration.zero),
          child: PushNotificationScope(
            push: push ?? const NoopPushNotifications(),
            child: withNotificationScope
                ? NotificationApiScope(api: api, child: app)
                : app,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('안 읽은 알림이 있으면 종에 점이 찍힌다', (tester) async {
    await pumpMyPage(tester, loggedIn: true);

    expect(hasDot(tester), isTrue);
  });

  testWidgets('안 읽은 알림이 없으면 점이 없다', (tester) async {
    await pumpMyPage(
      tester,
      loggedIn: true,
      scenario: MockNotificationScenario.empty,
    );

    expect(hasDot(tester), isFalse);
  });

  testWidgets('로그인 안 했으면 묻지 않는다', (tester) async {
    await pumpMyPage(tester, loggedIn: false);

    expect(hasDot(tester), isFalse);
  });

  testWidgets('개수를 물을 데가 없어도 화면은 그대로 뜬다', (tester) async {
    // 마이페이지만 띄우는 테스트나 알림을 안 붙인 실행. 점만 안 찍힌다.
    await pumpMyPage(tester, loggedIn: true, withNotificationScope: false);

    expect(find.byType(MyPageTopBar), findsOneWidget);
    expect(hasDot(tester), isFalse);
  });

  testWidgets('알림함에서 모두 읽고 돌아오면 점이 사라진다', (tester) async {
    await pumpMyPage(tester, loggedIn: true);
    expect(hasDot(tester), isTrue);

    // 종을 눌러 알림함으로.
    await tester.tap(find.byTooltip('알림'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // 목록이 뜨고 나서야 '모두 읽음' 버튼이 커지며 나타난다. 그 애니메이션이
    // 끝나기 전에는 눌러도 손가락이 닿지 않는다.
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(NotificationStrings.markAllRead));
    await tester.pump();
    await tester.pump();

    // 뒤로 나오면 마이페이지가 개수를 다시 묻는다.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(hasDot(tester), isFalse);
  });

  // 화면을 보고 있는 동안 푸시가 오면 다시 묻지 않고 푸시에 실린 개수로 맞춘다.
  group('앱이 켜진 채로 푸시가 오면', () {
    testWidgets('실린 개수로 점을 바로 켜고 끈다', (tester) async {
      final push = _FakePush();
      addTearDown(push.dispose);
      await pumpMyPage(
        tester,
        loggedIn: true,
        scenario: MockNotificationScenario.empty,
        push: push,
      );
      expect(hasDot(tester), isFalse);

      push.receive(2);
      // 한 프레임은 스트림이 개수를 넘기는 데, 한 프레임은 그리는 데 쓴다.
      await tester.pump();
      await tester.pump();
      expect(hasDot(tester), isTrue);

      push.receive(0);
      await tester.pump();
      await tester.pump();
      expect(hasDot(tester), isFalse);
    });

    testWidgets('로그아웃 상태면 받지 않는다', (tester) async {
      final push = _FakePush();
      addTearDown(push.dispose);
      await pumpMyPage(tester, loggedIn: false, push: push);

      push.receive(3);
      await tester.pump();
      await tester.pump();

      expect(hasDot(tester), isFalse);
    });
  });
}

/// 푸시가 왔다고 흉내 내는 가짜. 개수만 흘려보낸다.
class _FakePush implements PushNotifications {
  final _counts = StreamController<int>.broadcast();

  void receive(int unreadCount) => _counts.add(unreadCount);

  Future<void> dispose() => _counts.close();

  @override
  Stream<int> get unreadCounts => _counts.stream;

  @override
  Stream<int> get enteredTicketIds => const Stream.empty();

  @override
  NotificationDestination? takeLaunchDestination() => null;

  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> unregisterDevice() async {}
}
