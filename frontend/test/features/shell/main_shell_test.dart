import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/home/state/home_api_scope.dart';
import 'package:timo/features/mypage/constants.dart';
import 'package:timo/features/shell/constants.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';
import 'package:timo/features/shell/widgets/app_bottom_nav_bar.dart';
import 'package:timo/features/shell/widgets/mushroom_outline_icon.dart';
import 'package:timo/features/shell/widgets/quick_menu_button.dart';
import 'package:timo/routes/app_routes.dart';

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
    expect(
      find.descendant(of: quickMenuButton(), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
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
    expect(find.byType(MushroomOutlineIcon), findsOneWidget);
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

  test('입장QR 은 QR 화면으로 간다', () {
    final item = quickMenuItems.singleWhere((item) => item.label == '입장QR');
    expect(item.routeName, AppRoutes.entryQr);
  });

  test('카테고리 는 카테고리 화면으로 간다', () {
    final item = quickMenuItems.singleWhere((item) => item.label == '카테고리');
    expect(item.routeName, AppRoutes.categories);
  });

  test('환경 설정 은 설정 화면으로 간다', () {
    final item = quickMenuItems.singleWhere((item) => item.label == '환경 설정');
    expect(item.routeName, AppRoutes.settings);
  });

  /// 한때 카테고리와 환경 설정은 화면이 없어 '준비 중' 안내만 띄웠다. 이제
  /// 여덟 항목 모두 갈 곳이 있다. 항목을 새로 넣으면서 라우트를 빠뜨리면 눌러도
  /// 안내만 뜨는 항목이 되므로 여기서 잡는다.
  test('빠른 메뉴 항목은 모두 등록된 화면으로 간다', () {
    for (final item in quickMenuItems) {
      expect(item.routeName, isNotNull, reason: item.label);
      expect(AppRoutes.routes, contains(item.routeName), reason: item.label);
    }
  });
}
