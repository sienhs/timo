import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/state/home_api_scope.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/shell/constants.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';
import 'package:timo/features/shell/widgets/app_bottom_nav_bar.dart';
import 'package:timo/features/shell/widgets/quick_menu_button.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    // 홈 탭이 공연 API 를 위에서 찾는다. 앱에서는 App 이 내려주므로 여기서
    // 같은 것을 세워 준다.
    await tester.pumpWidget(
      const HomeApiScope(
        api: MockHomeApi(latency: Duration.zero),
        child: MaterialApp(home: MainShellScreen()),
      ),
    );
  }

  // 원형 버튼은 바 안이 아니라 Scaffold 가 띄운다.
  Finder quickMenuButton() => find.byType(QuickMenuButton);

  testWidgets('하단 바에 홈 · 빠른 메뉴 · 마이페이지가 있다', (tester) async {
    await pumpShell(tester);

    final bar = find.byType(AppBottomNavBar);
    expect(find.descendant(of: bar, matching: find.text('홈')), findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('빠른 메뉴')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('마이페이지')),
      findsOneWidget,
    );
    expect(quickMenuButton(), findsOneWidget);
  });

  testWidgets('+ 버튼은 바 위로 지름의 1/3 만 솟는다', (tester) async {
    await pumpShell(tester);

    final fab = tester.getRect(quickMenuButton());
    final bar = tester.getRect(find.byType(AppBottomNavBar));

    // 눈으로는 절반과 1/3 이 잘 구별되지 않아 수치로 굳힌다.
    expect(bar.top - fab.top, closeTo(ShellMetrics.fabProtrusion, 0.5));
    expect(fab.height, ShellMetrics.fabSize);
    // 바 밖으로 삐져나가지 않는다.
    expect(fab.bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets('탭을 바꿔도 하단 바는 그대로 있다', (tester) async {
    await pumpShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavBar),
        matching: find.text('마이페이지'),
      ),
    );
    await tester.pumpAndSettle();

    // 세션 스코프가 없어 로그아웃 상태의 마이페이지가 보인다.
    expect(find.text(MyPageStrings.loginPrompt), findsOneWidget);
    expect(find.byType(AppBottomNavBar), findsOneWidget);
    expect(quickMenuButton(), findsOneWidget);
  });

  testWidgets('+ 를 누르면 빠른 메뉴 8개가 시안 순서로 열린다', (tester) async {
    await pumpShell(tester);

    await tester.tap(quickMenuButton());
    await tester.pumpAndSettle();

    for (final item in quickMenuItems) {
      expect(find.text(item.label), findsWidgets, reason: item.label);
    }
    // 시안 순서(입장QR → ... → 환경 설정)가 목록 순서다.
    expect(quickMenuItems.map((item) => item.label).toList(), [
      '입장QR',
      '마이 티켓',
      '컬렉션',
      '찜',
      '버섯 충전',
      '양도마켓',
      '카테고리',
      '환경 설정',
    ]);
  });

  testWidgets('메뉴가 열려 있어도 하단 바와 + 버튼이 보인다', (tester) async {
    await pumpShell(tester);

    await tester.tap(quickMenuButton());
    await tester.pumpAndSettle();

    expect(find.byType(AppBottomNavBar), findsOneWidget);
    expect(quickMenuButton(), findsOneWidget);
  });

  testWidgets('패널 바깥을 누르면 닫힌다', (tester) async {
    await pumpShell(tester);

    await tester.tap(quickMenuButton());
    await tester.pumpAndSettle();
    expect(find.text('입장QR'), findsOneWidget);

    // 화면 위쪽(패널 밖)을 누른다.
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();

    expect(find.text('입장QR'), findsNothing);
  });

  testWidgets('화면이 없는 항목을 고르면 준비 중 안내가 뜬다', (tester) async {
    await pumpShell(tester);

    await tester.tap(quickMenuButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('입장QR'));
    await tester.pumpAndSettle();

    expect(find.text(ShellStrings.notReady('입장QR')), findsOneWidget);
  });
}
