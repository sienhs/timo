import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/models/show_filters.dart';
import 'package:timo/features/home/models/show_summary.dart';

/// 공연 전체 화면의 날짜·정렬 규칙. 화면 없이 값만 본다.
void main() {
  ShowSummary show(
    int id, {
    DateTime? startAt,
    DateTime? endAt,
    DateTime? ticketOpenAt,
  }) => ShowSummary(
    id: id,
    title: '공연 $id',
    venueName: '어딘가',
    status: ShowSummary.onSaleStatus,
    startAt: startAt,
    endAt: endAt,
    ticketOpenAt: ticketOpenAt,
  );

  group('ShowDateRange.accepts', () {
    final range = ShowDateRange(DateTime(2026, 10, 10), DateTime(2026, 10, 20));

    test('기간 안에서 시작하거나 끝나거나 걸치면 통과한다', () {
      expect(
        range.accepts(
          show(
            1,
            startAt: DateTime(2026, 10, 5),
            endAt: DateTime(2026, 10, 12),
          ),
        ),
        isTrue,
        reason: '앞에서 시작해 안에서 끝남',
      );
      expect(
        range.accepts(
          show(
            2,
            startAt: DateTime(2026, 10, 15),
            endAt: DateTime(2026, 11, 1),
          ),
        ),
        isTrue,
        reason: '안에서 시작해 뒤에서 끝남',
      );
      expect(
        range.accepts(
          show(3, startAt: DateTime(2026, 9, 1), endAt: DateTime(2026, 12, 31)),
        ),
        isTrue,
        reason: '기간을 통째로 덮음',
      );
    });

    test('양 끝 날은 포함이고 시각은 보지 않는다', () {
      expect(
        range.accepts(show(1, startAt: DateTime(2026, 10, 20, 23))),
        isTrue,
      );
      expect(
        range.accepts(
          show(
            2,
            startAt: DateTime(2026, 10, 1),
            endAt: DateTime(2026, 10, 10, 1),
          ),
        ),
        isTrue,
      );
    });

    test('기간 밖이거나 시작일이 없으면 떨어진다', () {
      expect(range.accepts(show(1, startAt: DateTime(2026, 10, 21))), isFalse);
      expect(
        range.accepts(
          show(2, startAt: DateTime(2026, 10, 1), endAt: DateTime(2026, 10, 9)),
        ),
        isFalse,
      );
      expect(range.accepts(show(3)), isFalse);
    });

    test('문구는 월.일 이고 하루면 하나만 적는다', () {
      expect(range.label, '10.10 ~ 10.20');
      expect(ShowDateRange.single(DateTime(2026, 10, 5, 19)).label, '10.05');
    });
  });

  group('ShowDatePreset.rangeFrom', () {
    test('이번 주말은 다가오는 토·일이다', () {
      final wednesday = DateTime(2026, 9, 23);
      expect(
        ShowDatePreset.thisWeekend.rangeFrom(wednesday),
        ShowDateRange(DateTime(2026, 9, 26), DateTime(2026, 9, 27)),
      );
    });

    test('토요일이면 오늘·내일, 일요일이면 오늘 하루다', () {
      expect(
        ShowDatePreset.thisWeekend.rangeFrom(DateTime(2026, 9, 26)),
        ShowDateRange(DateTime(2026, 9, 26), DateTime(2026, 9, 27)),
      );
      expect(
        ShowDatePreset.thisWeekend.rangeFrom(DateTime(2026, 9, 27)),
        ShowDateRange.single(DateTime(2026, 9, 27)),
      );
    });

    test('이번 달은 오늘부터 말일까지, 다음 달은 1일부터 말일까지다', () {
      final today = DateTime(2026, 9, 23, 15);
      expect(
        ShowDatePreset.thisMonth.rangeFrom(today),
        ShowDateRange(DateTime(2026, 9, 23), DateTime(2026, 9, 30)),
      );
      expect(
        ShowDatePreset.nextMonth.rangeFrom(today),
        ShowDateRange(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      );
    });

    test('연말이면 다음 달이 해를 넘긴다', () {
      expect(
        ShowDatePreset.nextMonth.rangeFrom(DateTime(2026, 12, 5)),
        ShowDateRange(DateTime(2027, 1, 1), DateTime(2027, 1, 31)),
      );
    });

    test('전체는 기간이 없다', () {
      expect(ShowDatePreset.all.rangeFrom(DateTime(2026, 9, 23)), isNull);
    });
  });

  group('ShowSort.apply', () {
    final late = show(1, startAt: DateTime(2026, 12, 1));
    final undecided = show(2);
    final early = show(3, startAt: DateTime(2026, 10, 1));
    final alsoEarly = show(4, startAt: DateTime(2026, 10, 1));
    final popular = [late, undecided, early, alsoEarly];

    test('인기순은 받은 순서 그대로다', () {
      expect(ShowSort.popular.apply(popular), popular);
    });

    test('공연일 빠른 순은 미정을 맨 뒤로 보내고 같은 날은 받은 순서를 지킨다', () {
      expect(ShowSort.startDate.apply(popular), [
        early,
        alsoEarly,
        late,
        undecided,
      ]);
    });

    test('오픈 임박순은 오픈 시각이 없는(이미 오픈한) 공연을 맨 뒤로 보낸다', () {
      final opened = show(1, startAt: DateTime(2026, 10, 1));
      final soon = show(2, ticketOpenAt: DateTime(2026, 9, 25));
      final later = show(3, ticketOpenAt: DateTime(2026, 10, 5));
      expect(ShowSort.openSoon.apply([opened, later, soon]), [
        soon,
        later,
        opened,
      ]);
    });

    test('원본은 건드리지 않는다', () {
      final copy = [...popular];
      ShowSort.startDate.apply(popular);
      expect(popular, copy);
    });
  });

  group('ShowCalendarSpan.covering', () {
    final today = DateTime(2026, 9, 23);

    test('공연이 없어도 최소 달 수는 펼친다', () {
      final span = ShowCalendarSpan.covering(const [], today: today);
      expect(span.firstMonth, DateTime(2026, 9));
      expect(span.monthCount, HomeMetrics.calendarMinMonths);
      expect(span.lastDay, DateTime(2026, 11, 30));
    });

    test('가장 먼 공연의 마지막 날이 있는 달까지 펼친다', () {
      final span = ShowCalendarSpan.covering([
        show(1, startAt: DateTime(2026, 11, 1), endAt: DateTime(2027, 2, 10)),
        show(2, startAt: DateTime(2026, 10, 1)),
      ], today: today);
      expect(span.monthCount, 6);
      expect(span.monthAt(5), DateTime(2027, 2));
    });

    test('아무리 멀어도 최대 달 수를 넘기지 않는다', () {
      final span = ShowCalendarSpan.covering([
        show(1, startAt: DateTime(2028, 1, 1)),
      ], today: today);
      expect(span.monthCount, HomeMetrics.calendarMaxMonths);
    });
  });

  group('countShowsByDay', () {
    test('공연 기간의 날마다 세고 겹치면 더한다', () {
      final counts = countShowsByDay(
        [
          show(1, startAt: DateTime(2026, 10, 1), endAt: DateTime(2026, 10, 3)),
          show(2, startAt: DateTime(2026, 10, 3, 19)),
          show(3),
        ],
        from: DateTime(2026, 9, 23),
        to: DateTime(2026, 11, 30),
      );
      expect(counts, {
        DateTime(2026, 10, 1): 1,
        DateTime(2026, 10, 2): 1,
        DateTime(2026, 10, 3): 2,
      });
    });

    test('달력 범위 밖은 세지 않는다', () {
      final counts = countShowsByDay(
        [show(1, startAt: DateTime(2026, 9, 20), endAt: DateTime(2026, 12, 2))],
        from: DateTime(2026, 9, 23),
        to: DateTime(2026, 11, 30),
      );
      expect(counts.containsKey(DateTime(2026, 9, 22)), isFalse);
      expect(counts[DateTime(2026, 9, 23)], 1);
      expect(counts[DateTime(2026, 11, 30)], 1);
      expect(counts.containsKey(DateTime(2026, 12, 1)), isFalse);
    });
  });
}
