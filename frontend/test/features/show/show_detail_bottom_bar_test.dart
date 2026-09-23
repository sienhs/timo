import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/show/constants.dart';
import 'package:timo/features/show/data/mock_show_detail_data.dart';
import 'package:timo/features/show/widgets/show_detail_bottom_bar.dart';

void main() {
  Widget bar() => MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox.expand()),
          ShowDetailBottomBar(
            detail: MockShowDetailData.sample,
            now: DateTime(2026, 9, 23),
            isOpenAlarmOn: false,
            isMarketAlarmOn: false,
            onBookPressed: () {},
            onOpenAlarmPressed: () {},
            onMarketAlarmPressed: () {},
          ),
        ],
      ),
    ),
  );

  double barHeight(WidgetTester tester) =>
      tester.getSize(find.byType(ShowDetailBottomBar)).height;

  Finder handle(String label) => find.bySemanticsLabel(label);

  /// 접히면 펼친 높이의 1/3 쯤 남는다.
  void expectCollapsed(WidgetTester tester, double expanded) {
    expect(
      barHeight(tester),
      moreOrLessEquals(
        expanded * ShowDetailMetrics.bottomBarCollapsedFraction,
        epsilon: 0.5,
      ),
    );
  }

  Finder arrow() => find.byIcon(Icons.keyboard_arrow_down_rounded);

  testWidgets('바를 끌어내리면 손잡이만 남고, 끌어올리면 다시 펴진다', (tester) async {
    await tester.pumpWidget(bar());
    final expanded = barHeight(tester);

    await tester.drag(find.byType(ShowDetailBottomBar), const Offset(0, 300));
    await tester.pumpAndSettle();
    expectCollapsed(tester, expanded);

    await tester.drag(find.byType(ShowDetailBottomBar), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(barHeight(tester), expanded);
  });

  testWidgets('손잡이를 누르면 접고 펴며, 스크린리더 이름도 따라 바뀐다', (tester) async {
    await tester.pumpWidget(bar());
    final expanded = barHeight(tester);

    expect(handle(ShowDetailStrings.collapseBottomBar), findsOneWidget);
    await tester.tap(arrow());
    await tester.pumpAndSettle();
    expectCollapsed(tester, expanded);

    expect(handle(ShowDetailStrings.expandBottomBar), findsOneWidget);
    await tester.tap(arrow());
    await tester.pumpAndSettle();
    expect(barHeight(tester), expanded);
  });

  testWidgets('조금만 끌다 놓으면 원래 자리로 돌아간다', (tester) async {
    await tester.pumpWidget(bar());
    final expanded = barHeight(tester);

    await tester.drag(find.byType(ShowDetailBottomBar), const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(barHeight(tester), expanded);
  });
}
