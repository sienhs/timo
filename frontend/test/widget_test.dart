import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/app.dart';
import 'package:timo/core/widgets/timo_logo.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';
import 'package:timo/features/splash/constants.dart';
import 'package:timo/features/splash/screens/splash_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 앱 시작 흐름. 로딩 화면 네 장면이 순서대로 보이고, 끝나면 홈으로 넘어간다.
/// 위젯 테스트의 시계는 가짜라 `pump(시간)` 으로 그만큼 흘려보내고, 타이머를 남겨
/// 둔 채 끝내면 실패하므로 로딩 화면을 띄운 테스트는 끝까지 돌려 홈에 닿게 한다.
void main() {
  /// 로딩 화면에서 시작하는 앱을 띄운다. 홈이 서버를 부르지 않게 목을 꽂는다.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const App(homeApi: MockHomeApi(latency: Duration.zero)),
    );
  }

  /// 로딩이 끝나 홈으로 넘어갈 때까지 시간을 돌리고, 화면 전환도 끝낸다. 이미
  /// 시간을 얼마쯤 흘렸어도 전체 길이를 또 돌린다 — 넘치게 돌려도 해롭지 않고,
  /// 모자라면 홈에 닿지 못한 채 타이머가 남아 실패한다.
  Future<void> finishSplash(WidgetTester tester) async {
    await tester.pump(SplashMetrics.totalDuration);
    await tester.pumpAndSettle();
  }

  testWidgets('앱을 켜면 로딩 첫 장면이 보이고 홈은 아직 없다', (tester) async {
    await pumpApp(tester);

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text(SplashStrings.tagline), findsOneWidget);
    expect(find.text(SplashStrings.wordmarks[0]), findsOneWidget);
    // 홈이 로딩 화면 밑에 몰래 쌓이면 안 된다 — 서버를 부르고, 로딩이 끝나
    // 홈으로 교체하면 홈이 둘이 된다.
    expect(find.byType(MainShellScreen), findsNothing);

    await finishSplash(tester);
  });

  testWidgets('장면이 ticket moa → TIcket MOa → TIMO → 로고 순으로 바뀐다', (
    tester,
  ) async {
    await pumpApp(tester);
    final steps = SplashMetrics.stepDurations;

    await tester.pump(steps[0]);
    expect(find.text(SplashStrings.wordmarks[1]), findsOneWidget);

    await tester.pump(steps[1]);
    expect(find.text(SplashStrings.wordmarks[2]), findsOneWidget);

    await tester.pump(steps[2]);
    expect(find.byType(TimoLogo), findsOneWidget);
    // 앞 장면은 크로스페이드가 끝나야 사라진다. pumpAndSettle 은 애니메이션 프레임만
    // 돌리고 타이머는 기다리지 않아, 로고 장면(0.9초)이 끝나기 전에 페이드(0.2초)만 마친다.
    await tester.pumpAndSettle();
    expect(find.text(SplashStrings.tagline), findsNothing);
    expect(find.byType(SplashScreen), findsOneWidget);

    await finishSplash(tester);
  });

  testWidgets('로딩이 끝나면 홈으로 넘어가고 로딩 화면은 남지 않는다', (tester) async {
    await pumpApp(tester);
    await finishSplash(tester);

    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    // 교체 이동이라 홈에서 뒤로 갈 곳이 없어야 한다. push 로 쌓았으면 뒤로
    // 가기가 로딩 화면으로 돌아간다.
    final navigator = Navigator.of(
      tester.element(find.byType(MainShellScreen)),
    );
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('첫 화면으로 홈을 넘기면 로딩을 건너뛴다', (tester) async {
    await tester.pumpWidget(
      const App(
        initialRoute: AppRoutes.home,
        homeApi: MockHomeApi(latency: Duration.zero),
      ),
    );

    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
