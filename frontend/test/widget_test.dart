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
///
/// 시간을 실제로 기다리지는 않는다. 위젯 테스트의 시계는 가짜라 `pump(시간)`
/// 으로 그만큼 흘려보내면 그 사이 만기가 된 타이머가 실행된다. 반대로 타이머를
/// 남겨 둔 채 테스트를 끝내면 실패로 잡히므로, 로딩 화면을 띄운 테스트는 끝까지
/// 돌려 홈에 닿게 한다.
void main() {
  /// 로딩 화면에서 시작하는 앱을 띄운다. 홈이 서버를 부르지 않게 목을 꽂는다.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      const App(homeApi: MockHomeApi(latency: Duration.zero)),
    );
  }

  /// 로딩이 끝나 홈으로 넘어갈 때까지 시간을 돌리고, 화면 전환도 끝낸다.
  ///
  /// 테스트가 이미 시간을 얼마쯤 흘려보냈어도 전체 길이를 또 돌린다. 넘치게
  /// 돌려도 해롭지 않다 — 타이머는 만기가 지나면 실행되고, 홈은 그 뒤에
  /// 그려진다. 반대로 모자라면 홈에 닿지 못한 채 타이머가 남아 실패한다.
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
    // 앞 장면은 크로스페이드가 끝나야 사라진다. 로고 장면에는 문구가 없다.
    //
    // 페이드 길이만큼만 `pump` 하면 한 프레임이 모자란다 — 애니메이션은 시작을
    // 부른 프레임이 아니라 그 다음 프레임부터 시간을 센다. pumpAndSettle 은
    // 애니메이션 프레임이 더 없을 때까지 돌리되 타이머는 기다리지 않으므로,
    // 로고 장면(0.9초)이 끝나기 전에 페이드(0.2초)만 마친다.
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
