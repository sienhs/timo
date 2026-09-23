import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/shell/widgets/app_bottom_nav_bar.dart';

/// 하단 바의 경계는 선이 아니라 그림자다. 리팩터링 중에 `BoxDecoration` 을 통째로
/// 갈아 끼우면 조용히 사라지므로 여기서 굳혀 둔다.
void main() {
  Widget host() => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: 0,
        onTabSelected: (_) {},
        onQuickMenuPressed: () {},
      ),
    ),
  );

  BoxDecoration barDecoration(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppBottomNavBar),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return box.decoration as BoxDecoration;
  }

  testWidgets('하단 바는 선이 아니라 그림자로 경계를 만든다', (tester) async {
    await tester.pumpWidget(host());

    final decoration = barDecoration(tester);
    expect(decoration.border, isNull, reason: '1px 선은 걷어냈다');
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('그림자는 위로만 퍼진다 — 아래는 화면 끝이라 퍼질 곳이 없다', (tester) async {
    await tester.pumpWidget(host());

    final shadow = barDecoration(tester).boxShadow!.first;
    expect(shadow.offset.dy, lessThan(0));
    expect(shadow.blurRadius, greaterThan(0));
  });
}
