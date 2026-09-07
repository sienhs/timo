import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/shell/constants.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';
import 'package:timo/features/shell/widgets/app_bottom_nav_bar.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainShellScreen()),
    );
  }

  Finder quickMenuButton() => find.descendant(
        of: find.byType(AppBottomNavBar),
        matching: find.byIcon(Icons.add),
      );

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

  testWidgets('탭을 바꿔도 하단 바는 그대로 있다', (tester) async {
    await pumpShell(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNavBar),
        matching: find.text('마이페이지'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('마이페이지는 준비 중이에요.'), findsOneWidget);
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
    expect(
      quickMenuItems.map((item) => item.label).toList(),
      ['입장QR', '마이 티켓', '컬렉션', '찜', '코인 충전', '양도마켓', '카테고리', '환경 설정'],
    );
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
