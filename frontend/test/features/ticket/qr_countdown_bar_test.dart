import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_colors.dart';
import 'package:timo/features/ticket/constants.dart';
import 'package:timo/features/ticket/widgets/qr_countdown_bar.dart';

/// 입장 QR 화면의 남은 시간 표시. 색이 바뀌는 경계와 화면 읽기 문구를 본다.
void main() {
  const lifetime = Duration(seconds: 30);

  Future<void> pumpBar(WidgetTester tester, Duration remaining) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QrCountdownBar(
              remaining: remaining,
              progress: remaining.inMilliseconds / lifetime.inMilliseconds,
            ),
          ),
        ),
      );

  // `valueColor` 는 `Animation<Color?>` 라 구체 타입으로 캐스팅하지 않고 값만 읽는다.
  Color barColor(WidgetTester tester) => tester
      .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .valueColor!
      .value!;

  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;

  testWidgets('여유가 있으면 브랜드색으로 남은 초를 보여준다', (tester) async {
    await pumpBar(tester, const Duration(seconds: 20));

    expect(find.text('00:20'), findsOneWidget);
    expect(barColor(tester), AppColors.primary);
    expect(labelColor(tester, '00:20'), AppColors.textPrimary);
  });

  // 검표기가 읽고 서버가 판정하는 데 1~2초가 든다. 마지막 몇 초는 내밀지
  // 말고 새로 받으라는 신호다.
  testWidgets('경고 기준 안쪽이면 숫자와 막대가 경고색이 된다', (tester) async {
    await pumpBar(tester, TicketMetrics.qrWarningThreshold);

    expect(barColor(tester), AppColors.accent);
    expect(labelColor(tester, '00:05'), AppColors.accent);
  });

  testWidgets('경고 기준보다 1초 더 남았으면 아직 브랜드색이다', (tester) async {
    await pumpBar(
      tester,
      TicketMetrics.qrWarningThreshold + const Duration(seconds: 1),
    );

    expect(barColor(tester), AppColors.primary);
    expect(labelColor(tester, '00:06'), AppColors.textPrimary);
  });

  // 만료된 QR 위에는 새로고침 버튼이 따로 뜨지만, 숫자도 같은 말을 해야 한다.
  testWidgets('만료된 뒤에도 경고색을 유지한다', (tester) async {
    await pumpBar(tester, Duration.zero);

    expect(find.text('00:00'), findsOneWidget);
    expect(barColor(tester), AppColors.accent);
    expect(labelColor(tester, '00:00'), AppColors.accent);
  });

  // 진행 바는 눈으로만 읽히므로 화면 읽기 프로그램에는 초를 말로 준다.
  testWidgets('화면 읽기 프로그램에는 남은 초를 말로 준다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBar(tester, const Duration(seconds: 20));

    expect(
      find.bySemanticsLabel(TicketStrings.qrRemainingSemantics(20)),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
