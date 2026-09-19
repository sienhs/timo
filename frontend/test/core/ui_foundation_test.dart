import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/core/widgets/app_action_button.dart';
import 'package:timo/core/widgets/app_search_field.dart';

Widget host(Widget child, {double scale = 1}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Center(child: SizedBox(width: 248, child: child)),
    ),
  ),
);

void main() {
  testWidgets('긴 버튼 문구는 글자 확대 시 높이가 늘고 동작을 유지한다', (tester) async {
    var taps = 0;
    const label = '선택한 티켓을 확인하고 결제하기';
    final button = AppActionButton(label: label, onPressed: () => taps++);
    await tester.pumpWidget(host(button));
    final normalHeight = tester.getSize(find.byType(FilledButton)).height;
    await tester.pumpWidget(host(button, scale: 2));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThan(normalHeight),
    );
    await tester.tap(find.text(label));
    expect(taps, 1);
  });

  testWidgets('처리 중 버튼은 크기를 유지하고 중복 실행을 막는다', (tester) async {
    var taps = 0;
    AppActionButton button(bool busy) =>
        AppActionButton(label: '결제하기', onPressed: () => taps++, isBusy: busy);
    await tester.pumpWidget(host(button(false)));
    final size = tester.getSize(find.byType(FilledButton));
    await tester.pumpWidget(host(button(true)));
    expect(tester.getSize(find.byType(FilledButton)), size);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('검색 입력·제출·외부 변경·지우기는 각각 계약대로 전달된다', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    final submissions = <String>[];
    var clears = 0;
    await tester.pumpWidget(
      host(
        AppSearchField(
          controller: controller,
          hintText: '공연 검색',
          onChanged: changes.add,
          onSubmitted: submissions.add,
          onCleared: () => clears++,
        ),
        scale: 2,
      ),
    );
    await tester.enterText(find.byType(TextField), '긴 공연명');
    expect(changes, ['긴 공연명']);
    expect(submissions, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submissions, ['긴 공연명']);
    controller.text = '외부에서 변경한 검색어';
    await tester.pump();
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes, ['긴 공연명', '']);
    expect(clears, 1);
    expect(find.byTooltip('검색어 지우기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색창 포커스 전후 모서리를 유지하고 비활성 입력을 막는다', (tester) async {
    final controller = TextEditingController(text: '검색어');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(AppSearchField(controller: controller, hintText: '검색')),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderRadius,
      (decoration.focusedBorder! as OutlineInputBorder).borderRadius,
    );
    await tester.pumpWidget(
      host(
        AppSearchField(controller: controller, hintText: '검색', enabled: false),
      ),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(controller.text, '검색어');
  });
}
