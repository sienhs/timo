import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/core/widgets/timo_mascot.dart';
import 'package:timo/features/resale/constants.dart';
import 'package:timo/features/resale/widgets/resale_empty_view.dart';

/// 빈 상태를 화면 본문 자리(높이가 정해진 자리)에 놓는다. 실제 화면들도
/// `Expanded` 안에 넣어 쓴다.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size surface = const Size(400, 800),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(children: [Expanded(child: child)]),
      ),
    ),
  );
}

void main() {
  testWidgets('빈 상태는 우는 티모와 안내를 함께 보여 준다', (tester) async {
    await _pump(
      tester,
      const ResaleEmptyView(message: ResaleStrings.emptyTickets),
    );

    expect(find.byType(TimoMascot), findsOneWidget);
    expect(find.text(ResaleStrings.emptyTickets), findsOneWidget);
  });

  testWidgets('로그인 안내처럼 마스코트를 끈 자리에는 그리지 않는다', (tester) async {
    await _pump(
      tester,
      const ResaleEmptyView(
        message: ResaleStrings.loginPrompt,
        showMascot: false,
      ),
    );

    expect(find.byType(TimoMascot), findsNothing);
    expect(find.text(ResaleStrings.loginPrompt), findsOneWidget);
  });

  testWidgets('자리가 마스코트보다 좁아도 넘치지 않고 밀어서 볼 수 있다', (tester) async {
    // 작은 기기에서 검색 키보드까지 올라온 만큼의 높이. 마스코트(150)와 안내를
    // 세로로 쌓으면 이 높이를 넘는다.
    await _pump(
      tester,
      const ResaleEmptyView(message: ResaleStrings.emptyTickets),
      surface: const Size(320, 200),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.text(ResaleStrings.emptyTickets), findsOneWidget);
  });
}
