import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/notification/notification_destination.dart';
import 'package:timo/features/notification/push_notification_scope.dart';
import 'package:timo/features/notification/push_notification_service.dart';
import 'package:timo/features/splash/constants.dart';
import 'package:timo/features/splash/screens/splash_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 알림을 눌러 앱이 켜졌을 때, 로딩 화면이 홈을 세운 뒤 그 알림의 화면까지 여는지.
///
/// 이게 깨지기 쉬운 자리다. 로딩 화면은 홈으로 갈 때 맨 위 화면을 **갈아치우는**
/// 방식을 쓴다. 알림 목적지를 그보다 먼저 열어 두면 홈이 그걸 덮어써 사라진다.
///
/// 홈·공연 상세·마켓은 진짜 화면 대신 빈 화면으로 바꿔 끼운다. 여기서 볼 것은 어느
/// 화면이 어떤 순서로 쌓이느냐지 그 화면들의 내용이 아니다.
void main() {
  const homeLabel = '홈';
  const marketLabel = '마켓';

  final routes = <String, WidgetBuilder>{
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.home: (_) => const Scaffold(body: Text(homeLabel)),
    AppRoutes.resaleMarket: (_) => const Scaffold(body: Text(marketLabel)),
    AppRoutes.showDetail: (context) => Scaffold(
      body: Text('공연 ${ModalRoute.of(context)!.settings.arguments}'),
    ),
  };

  /// 로딩 화면 하나만 깔고 시작한다. 진짜 앱도 이렇게 시작한다 — 주소를 '/' 부터
  /// 쪼개 여러 장을 깔아 두면 홈이 두 번 쌓여 무엇이 어디 있는지 흐려진다.
  MaterialApp buildApp() => MaterialApp(
    initialRoute: AppRoutes.splash,
    onGenerateInitialRoutes: (name) => [
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: routes[name]!,
      ),
    ],
    routes: routes,
  );

  /// 장면 넷을 차례로 넘긴 뒤 화면 전환이 끝날 때까지.
  ///
  /// 장면마다 타이머가 이어 달리므로 한 번에 몰아 보내면 안 되고 장면 길이대로
  /// 하나씩 보낸다. 마지막 둘은 화면 전환 애니메이션을 넘기는 시간이다.
  Future<void> runSplash(WidgetTester tester) async {
    for (final step in SplashMetrics.stepDurations) {
      await tester.pump(step);
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  testWidgets('알림으로 켜졌으면 홈을 세운 뒤 그 화면을 위에 연다', (tester) async {
    final push = _FakePush(
      const NotificationDestination(AppRoutes.showDetail, arguments: 12),
    );

    await tester.pumpWidget(
      PushNotificationScope(push: push, child: buildApp()),
    );
    await runSplash(tester);

    // 알림이 가리킨 화면이 열렸다. 홈이 덮어쓰지 않았다.
    expect(find.text('공연 12'), findsOneWidget);

    // 홈은 그 아래에 있다. 뒤로가기로 돌아올 자리다. 알림으로 들어왔다고 뒤로가기에
    // 앱이 꺼지면 안 된다.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('그냥 켰으면 홈에서 멈춘다', (tester) async {
    final push = _FakePush(null);

    await tester.pumpWidget(
      PushNotificationScope(push: push, child: buildApp()),
    );
    await runSplash(tester);

    expect(find.text(homeLabel), findsOneWidget);
  });

  testWidgets('목적지는 한 번만 쓰인다', (tester) async {
    // 앱을 잠깐 내렸다 다시 봤을 때 같은 화면이 또 열리면 안 된다.
    final push = _FakePush(
      const NotificationDestination(AppRoutes.resaleMarket),
    );

    await tester.pumpWidget(
      PushNotificationScope(push: push, child: buildApp()),
    );
    await runSplash(tester);

    expect(find.text(marketLabel), findsOneWidget);
    expect(push.takeCalls, 1);
    expect(push.takeLaunchDestination(), isNull);
  });

  testWidgets('스코프가 없어도 홈까지는 간다', (tester) async {
    // 로딩 화면만 띄우는 테스트나 푸시를 안 붙인 실행에서도 앱은 켜져야 한다.
    await tester.pumpWidget(buildApp());
    await runSplash(tester);

    expect(find.text(homeLabel), findsOneWidget);
  });
}

/// 알림 목적지를 하나 들고 있다가 한 번만 내주는 가짜.
class _FakePush implements PushNotifications {
  _FakePush(this._destination);

  NotificationDestination? _destination;
  int takeCalls = 0;

  @override
  NotificationDestination? takeLaunchDestination() {
    takeCalls++;
    final taken = _destination;
    _destination = null;
    return taken;
  }

  /// 로딩 화면은 이 둘을 쓰지 않는다. 기기 해제는 마이페이지가, 등록은 App 이 부른다.
  @override
  Future<void> unregisterDevice() async {}

  @override
  Future<void> registerDevice() async {}
}
