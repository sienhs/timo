import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_filters.dart';

/// 세로로 넘기며 기간을 고르는 달력. 첫 탭이 시작, 다음 탭이 끝이다 — 어느
/// 날을 무엇으로 삼을지는 부모가 [onDayPressed] 에서 정하고, 여기서는
/// [start]·[end] 를 받아 그릴 뿐이다. 오늘 이전은 흐리게 두고 누를 수 없다.
/// 공연이 있는 날은 [countByDay] 를 보고 아래에 점을 찍는다.
class RangeCalendar extends StatelessWidget {
  const RangeCalendar({
    super.key,
    required this.span,
    required this.today,
    required this.onDayPressed,
    this.start,
    this.end,
    this.countByDay = const {},
    this.padding = EdgeInsets.zero,
  });

  final ShowCalendarSpan span;

  /// 이 날 앞은 고를 수 없다. 테스트가 고정할 수 있게 받는다.
  final DateTime today;

  /// 고른 기간의 양 끝. 시작만 골랐으면 [end] 는 null 이다.
  final DateTime? start;
  final DateTime? end;

  final ValueChanged<DateTime> onDayPressed;

  /// 날짜(자정)별 공연 수. 없는 날은 점을 찍지 않는다.
  final Map<DateTime, int> countByDay;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: span.monthCount,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(
          bottom: index == span.monthCount - 1
              ? 0
              : HomeMetrics.calendarMonthGap,
        ),
        child: _Month(
          month: span.monthAt(index),
          today: ShowDateRange.dateOnly(today),
          start: start,
          end: end,
          countByDay: countByDay,
          onDayPressed: onDayPressed,
        ),
      ),
    );
  }
}

class _Month extends StatelessWidget {
  const _Month({
    required this.month,
    required this.today,
    required this.start,
    required this.end,
    required this.countByDay,
    required this.onDayPressed,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final Map<DateTime, int> countByDay;
  final ValueChanged<DateTime> onDayPressed;

  static const _daysPerWeek = 7;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // `weekday` 는 월요일이 1, 일요일이 7 이다. 일요일부터 시작하는 줄에서의
    // 자리는 7 로 나눈 나머지다.
    final leadingBlanks = month.weekday % _daysPerWeek;
    final cellCount = leadingBlanks + daysInMonth;
    final weekCount = (cellCount / _daysPerWeek).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            HomeStrings.calendarMonth(month),
            style: textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: HomeMetrics.calendarMonthTitleGap),
        Row(
          children: [
            for (final weekday in HomeStrings.calendarWeekdays)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: HomeMetrics.calendarWeekdayGap),
        for (var week = 0; week < weekCount; week++)
          Row(
            children: [
              for (var column = 0; column < _daysPerWeek; column++)
                Expanded(
                  child: _cellAt(
                    week * _daysPerWeek + column - leadingBlanks + 1,
                    daysInMonth,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cellAt(int dayOfMonth, int daysInMonth) {
    if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
      return const SizedBox(height: HomeMetrics.calendarCellHeight);
    }
    final day = DateTime(month.year, month.month, dayOfMonth);
    final rangeStart = start;
    final rangeEnd = end;
    final isStart = day == rangeStart;
    final isEnd = day == rangeEnd;
    // 시작만 골랐을 때는 그날 하나만 칠한다. 끝이 정해지면 사이를 띠로 잇는다.
    final isBetween =
        rangeStart != null &&
        rangeEnd != null &&
        day.isAfter(rangeStart) &&
        day.isBefore(rangeEnd);
    final hasBandLeft = isBetween || (isEnd && rangeStart != rangeEnd);
    final hasBandRight =
        isBetween || (isStart && rangeEnd != null && rangeStart != rangeEnd);

    return _DayCell(
      day: day,
      isToday: day == today,
      isPast: day.isBefore(today),
      isEndpoint: isStart || isEnd,
      hasBandLeft: hasBandLeft,
      hasBandRight: hasBandRight,
      showCount: countByDay[day] ?? 0,
      onPressed: () => onDayPressed(day),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isPast,
    required this.isEndpoint,
    required this.hasBandLeft,
    required this.hasBandRight,
    required this.showCount,
    required this.onPressed,
  });

  final DateTime day;
  final bool isToday;
  final bool isPast;
  final bool isEndpoint;

  /// 구간 띠가 이 칸의 왼쪽·오른쪽 절반에 깔리는가. 사이 날은 둘 다,
  /// 시작은 오른쪽만, 끝은 왼쪽만이다.
  final bool hasBandLeft;
  final bool hasBandRight;
  final int showCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : HomeMetrics.calendarSelectDuration;

    // 고른 날은 진한 브랜드색 원 위에 흰 굵은 글자다. 브랜드 그린 위 흰 글자는
    // 작은 글자 대비(4.5:1)에 못 미쳐 [AppColors.primaryPressed] 를 쓰고 굵기도
    // 바꾼다. 오늘은 색과 굵기 둘로 표시해 색만으로 가르지 않는다.
    final Color textColor;
    if (isPast) {
      textColor = AppColors.textDisabled;
    } else if (isEndpoint) {
      textColor = AppColors.onPrimary;
    } else if (isToday) {
      textColor = AppColors.primaryPressed;
    } else {
      textColor = AppColors.textPrimary;
    }
    final fontWeight = isEndpoint || isToday
        ? FontWeight.w700
        : FontWeight.w500;

    return Semantics(
      label: HomeStrings.calendarDay(day, showCount: showCount),
      selected: isEndpoint || hasBandLeft || hasBandRight,
      enabled: !isPast,
      button: !isPast,
      excludeSemantics: true,
      child: SizedBox(
        height: HomeMetrics.calendarCellHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 구간 띠. 칸의 절반씩 깔아 이웃 칸의 띠와 이어진다.
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      color: hasBandLeft
                          ? AppColors.primarySurface
                          : Colors.transparent,
                    ),
                  ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      color: hasBandRight
                          ? AppColors.primarySurface
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: duration,
              width: HomeMetrics.calendarDayCircleSize,
              height: HomeMetrics.calendarDayCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEndpoint
                    ? AppColors.primaryPressed
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: fontWeight,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: HomeMetrics.calendarDotGap),
                  // 점 자리는 공연이 없어도 비워 둔다. 있고 없고에 따라 숫자
                  // 높이가 달라지면 줄이 들쭉날쭉해진다.
                  SizedBox.square(
                    dimension: HomeMetrics.calendarDotSize,
                    child: showCount > 0
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isEndpoint
                                  ? AppColors.onPrimary
                                  : isPast
                                  ? AppColors.textDisabled
                                  : AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            if (!isPast)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onPressed,
                    customBorder: const CircleBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
