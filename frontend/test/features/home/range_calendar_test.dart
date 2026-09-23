import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/theme/app_theme.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/models/show_filters.dart';
import 'package:timo/features/home/widgets/range_calendar.dart';

/// 기간 고르는 달력. 한 달만 펼쳐 날짜 글자가 하나씩만 있게 하고 본다.
void main() {
  final today = DateTime(2026, 10, 10);
  final span = ShowCalendarSpan(firstMonth: DateTime(2026, 10), monthCount: 1);

  Future<List<DateTime>> pumpCalendar(
    WidgetTester tester, {
    DateTime? start,
    DateTime? end,
    Map<DateTime, int> countByDay = const {},
  }) async {
    final pressed = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: RangeCalendar(
            span: span,
            today: today,
            start: start,
            end: end,
            countByDay: countByDay,
            onDayPressed: pressed.add,
          ),
        ),
      ),
    );
    return pressed;
  }

  testWidgets('달 제목과 요일 줄을 그린다', (tester) async {
    await pumpCalendar(tester);

    expect(
      find.text(HomeStrings.calendarMonth(DateTime(2026, 10))),
      findsOneWidget,
    );
    for (final weekday in HomeStrings.calendarWeekdays) {
      expect(find.text(weekday), findsOneWidget);
    }
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('오늘 이후 날을 누르면 그 날짜가 올라온다', (tester) async {
    final pressed = await pumpCalendar(tester);

    await tester.tap(find.text('15'));
    await tester.pump();

    expect(pressed, [DateTime(2026, 10, 15)]);
  });

  testWidgets('지난 날은 눌러도 아무 일도 없다', (tester) async {
    final pressed = await pumpCalendar(tester);

    await tester.tap(find.text('5'), warnIfMissed: false);
    await tester.pump();

    expect(pressed, isEmpty);
  });

  testWidgets('공연이 있는 날은 스크린 리더에 건수까지 읽힌다', (tester) async {
    await pumpCalendar(tester, countByDay: {DateTime(2026, 10, 15): 2});

    expect(
      find.bySemanticsLabel(
        HomeStrings.calendarDay(DateTime(2026, 10, 15), showCount: 2),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        HomeStrings.calendarDay(DateTime(2026, 10, 16), showCount: 0),
      ),
      findsOneWidget,
    );
  });

  testWidgets('고른 양 끝과 사이 날은 선택된 것으로 읽힌다', (tester) async {
    await pumpCalendar(
      tester,
      start: DateTime(2026, 10, 12),
      end: DateTime(2026, 10, 14),
    );

    void expectSelected(int day, {required bool selected}) {
      final node = tester.getSemantics(
        find.bySemanticsLabel(
          HomeStrings.calendarDay(DateTime(2026, 10, day), showCount: 0),
        ),
      );
      expect(node, isSemantics(isSelected: selected), reason: '$day일');
    }

    expectSelected(12, selected: true);
    expectSelected(13, selected: true);
    expectSelected(14, selected: true);
    expectSelected(11, selected: false);
    expectSelected(15, selected: false);
  });
}
