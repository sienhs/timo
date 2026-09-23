import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';
import 'show_summary.dart';

/// 공연 전체 화면의 정렬. 순서가 메뉴의 순서다. 서버에 다시 묻지 않고 받아 둔
/// 목록을 그 자리에서 다시 세운다 — 날짜·검색어로 거른 뒤에 적용해도 순서가
/// 맞고, 바꿀 때 기다리지 않는다.
enum ShowSort {
  popular(HomeStrings.sortPopular),
  startDate(HomeStrings.sortStartDate),
  openSoon(HomeStrings.sortOpenSoon);

  const ShowSort(this.label);

  final String label;

  /// 서버가 인기순으로 주므로 [popular] 는 그대로다. [startDate] 는 공연일이
  /// 빠른 것부터, [openSoon] 은 오픈 시각이 빠른 것부터다. 둘 다 값이 없는
  /// 공연(일정 미정 · 이미 오픈)은 받은 순서를 지킨 채 맨 뒤로 보낸다 —
  /// 백엔드 정렬(`nullsLast`)과 같은 규칙이다.
  List<ShowSummary> apply(List<ShowSummary> shows) => switch (this) {
    popular => shows,
    startDate => _stableSortBy(shows, (show) => show.startAt),
    openSoon => _stableSortBy(shows, (show) => show.ticketOpenAt),
  };

  /// `List.sort` 는 안정 정렬이 아니라 같은 값끼리의 순서가 뒤바뀔 수 있다.
  /// 색인을 마지막 비교 키로 붙여 받은 순서를 지킨다.
  static List<ShowSummary> _stableSortBy(
    List<ShowSummary> shows,
    DateTime? Function(ShowSummary) keyOf,
  ) {
    final indexed = shows.indexed.toList()
      ..sort((a, b) {
        final aKey = keyOf(a.$2);
        final bKey = keyOf(b.$2);
        if (aKey == null && bKey == null) return a.$1.compareTo(b.$1);
        if (aKey == null) return 1;
        if (bKey == null) return -1;
        final byKey = aKey.compareTo(bKey);
        return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
      });
    return [for (final (_, show) in indexed) show];
  }
}

/// 날짜로 좁히는 기간. 시각 없이 날짜만 보고, 양 끝을 포함한다. 하루만 고르면
/// 시작과 끝이 같다. 화면은 이 값이 null 이면 "전체 기간"으로 본다.
@immutable
class ShowDateRange {
  ShowDateRange(DateTime start, DateTime end)
    : assert(!end.isBefore(start), 'end must not be before start'),
      start = dateOnly(start),
      end = dateOnly(end);

  ShowDateRange.single(DateTime day) : this(day, day);

  final DateTime start;
  final DateTime end;

  bool get isSingleDay => start == end;

  /// 공연이 이 기간과 하루라도 겹치는가. 공연 기간은 `[startAt, endAt]` 이고
  /// 마지막 날이 없으면 하루 공연이다. 시작일이 정해지지 않은 공연은 어느
  /// 기간에도 들지 않는다 — 언제인지 모르는 공연을 "이 날 공연" 으로 보여
  /// 줄 수는 없다.
  bool accepts(ShowSummary show) {
    final showStart = show.startAt;
    if (showStart == null) return false;
    final showEnd = show.endAt ?? showStart;
    return !dateOnly(showStart).isAfter(end) &&
        !dateOnly(showEnd).isBefore(start);
  }

  bool contains(DateTime day) {
    final date = dateOnly(day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  /// 칩과 시트 제목에 찍는 문구. (예: `09.23 ~ 10.05`, 하루면 `10.05`)
  String get label => isSingleDay
      ? formatMonthDay(start)
      : '${formatMonthDay(start)} ~ ${formatMonthDay(end)}';

  /// 시각을 버린 자정. 기간 비교는 전부 이 값으로 한다.
  static DateTime dateOnly(DateTime at) => DateTime(at.year, at.month, at.day);

  @override
  bool operator ==(Object other) =>
      other is ShowDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ShowDateRange($label)';
}

/// 시트 위의 빠른 선택. 순서가 칩 줄의 순서다. 지난 날은 고를 수 없으므로
/// 오늘을 넘기지 않는 쪽으로 잘라 만든다.
enum ShowDatePreset {
  all(HomeStrings.presetAll),
  thisWeekend(HomeStrings.presetThisWeekend),
  thisMonth(HomeStrings.presetThisMonth),
  nextMonth(HomeStrings.presetNextMonth);

  const ShowDatePreset(this.label);

  final String label;

  /// [today] 기준의 기간. [all] 은 null(전체 기간)이다.
  ShowDateRange? rangeFrom(DateTime today) {
    final date = ShowDateRange.dateOnly(today);
    switch (this) {
      case all:
        return null;
      case thisWeekend:
        // 토·일. 오늘이 일요일이면 오늘 하루, 토요일이면 오늘·내일이다.
        final daysToSunday = DateTime.sunday - date.weekday;
        final sunday = DateTime(date.year, date.month, date.day + daysToSunday);
        final saturday = DateTime(sunday.year, sunday.month, sunday.day - 1);
        return ShowDateRange(saturday.isBefore(date) ? date : saturday, sunday);
      case thisMonth:
        return ShowDateRange(date, _lastDayOf(date.year, date.month));
      case nextMonth:
        final first = DateTime(date.year, date.month + 1);
        return ShowDateRange(first, _lastDayOf(first.year, first.month));
    }
  }

  /// `DateTime` 은 달을 넘긴 날짜를 다음 달로 넘겨 주므로 다음 달 0일이
  /// 이 달의 마지막 날이다.
  static DateTime _lastDayOf(int year, int month) =>
      DateTime(year, month + 1, 0);
}

/// 달력이 펼칠 달의 범위. 오늘이 있는 달부터 시작해 공연이 있는 마지막
/// 달까지 펼치되, 최소 [HomeMetrics.calendarMinMonths] 달, 최대
/// [HomeMetrics.calendarMaxMonths] 달이다.
@immutable
class ShowCalendarSpan {
  const ShowCalendarSpan({required this.firstMonth, required this.monthCount});

  /// [shows] 를 다 담을 만큼 펼친다. 공연이 없거나 전부 지났으면 최소치다.
  factory ShowCalendarSpan.covering(
    List<ShowSummary> shows, {
    required DateTime today,
  }) {
    final first = DateTime(today.year, today.month);
    var months = HomeMetrics.calendarMinMonths;
    for (final show in shows) {
      final last = show.endAt ?? show.startAt;
      if (last == null) continue;
      final gap =
          (last.year - first.year) * 12 + (last.month - first.month) + 1;
      if (gap > months) months = gap;
    }
    return ShowCalendarSpan(
      firstMonth: first,
      monthCount: months.clamp(
        HomeMetrics.calendarMinMonths,
        HomeMetrics.calendarMaxMonths,
      ),
    );
  }

  /// 첫 달의 1일.
  final DateTime firstMonth;
  final int monthCount;

  /// [index] 번째 달의 1일.
  DateTime monthAt(int index) =>
      DateTime(firstMonth.year, firstMonth.month + index);

  /// 마지막 달의 마지막 날. 이 뒤의 날은 달력에 없다.
  DateTime get lastDay =>
      DateTime(firstMonth.year, firstMonth.month + monthCount, 0);
}

/// 날짜마다 그날 하는 공연 수. 달력의 점과 스크린 리더 라벨이 쓴다. [from] 과
/// [to] 밖은 세지 않는다 — 달력에 없는 날을 세어 둘 이유가 없고, 마지막 날이
/// 먼 장기 공연 하나가 수백 칸을 만들지 않게 한다.
Map<DateTime, int> countShowsByDay(
  List<ShowSummary> shows, {
  required DateTime from,
  required DateTime to,
}) {
  final first = ShowDateRange.dateOnly(from);
  final last = ShowDateRange.dateOnly(to);
  final counts = <DateTime, int>{};
  for (final show in shows) {
    final start = show.startAt;
    if (start == null) continue;
    var day = ShowDateRange.dateOnly(start);
    final end = ShowDateRange.dateOnly(show.endAt ?? start);
    if (day.isBefore(first)) day = first;
    final stop = end.isAfter(last) ? last : end;
    while (!day.isAfter(stop)) {
      counts.update(day, (count) => count + 1, ifAbsent: () => 1);
      // `add(Duration(days: 1))` 은 서머타임 경계에서 23시간 뒤가 같은 날일 수
      // 있다. 날짜 산술로 하루를 넘긴다.
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }
  return counts;
}
