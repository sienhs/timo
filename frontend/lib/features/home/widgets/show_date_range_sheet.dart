import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_action_button.dart';
import '../constants.dart';
import '../models/show_filters.dart';
import '../models/show_summary.dart';
import 'range_calendar.dart';

/// 공연 전체 화면의 날짜 선택 시트. 위에 빠른 선택 칩, 가운데 세로 달력, 아래에
/// 초기화·적용 버튼이다. 고른 결과는 닫히면서 [onApplied] 로 넘긴다 — 전체
/// 기간으로 되돌리는 것(null)과 그냥 닫는 것을 반환값 하나로 가를 수 없어
/// 콜백으로 받는다. [shows] 는 점을 찍고 건수를 세는 데 쓴다.
Future<void> showShowDateRangeSheet(
  BuildContext context, {
  required List<ShowSummary> shows,
  required ShowDateRange? initial,
  required DateTime today,
  required ValueChanged<ShowDateRange?> onApplied,
}) {
  final height =
      MediaQuery.sizeOf(context).height * HomeMetrics.dateSheetHeightFraction;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(HomeMetrics.sheetRadius),
      ),
    ),
    builder: (context) => SizedBox(
      height: height,
      child: _DateRangeSheet(
        shows: shows,
        initial: initial,
        today: today,
        onApplied: onApplied,
      ),
    ),
  );
}

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({
    required this.shows,
    required this.initial,
    required this.today,
    required this.onApplied,
  });

  final List<ShowSummary> shows;
  final ShowDateRange? initial;
  final DateTime today;
  final ValueChanged<ShowDateRange?> onApplied;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late final ShowCalendarSpan _span = ShowCalendarSpan.covering(
    widget.shows,
    today: widget.today,
  );
  late final Map<DateTime, int> _countByDay = countShowsByDay(
    widget.shows,
    from: widget.today,
    to: _span.lastDay,
  );

  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initial?.start;
    _end = widget.initial?.end;
  }

  /// 지금까지 고른 것으로 만든 기간. 시작만 골랐으면 하루짜리다.
  ShowDateRange? get _range {
    final start = _start;
    if (start == null) return null;
    return ShowDateRange(start, _end ?? start);
  }

  /// 에어비앤비식 두 번 탭. 아무것도 없거나 이미 둘 다 골랐으면 새 시작이고,
  /// 시작만 있는데 그보다 앞을 누르면 시작을 옮기고, 뒤를 누르면 끝이다.
  void _pressDay(DateTime day) {
    setState(() {
      final start = _start;
      if (start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(start)) {
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  void _pickPreset(ShowDatePreset preset) {
    final range = preset.rangeFrom(widget.today);
    setState(() {
      _start = range?.start;
      _end = range?.end;
    });
  }

  void _reset() => setState(() {
    _start = null;
    _end = null;
  });

  void _apply() {
    widget.onApplied(_range);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final range = _range;
    final matchCount = range == null
        ? widget.shows.length
        : widget.shows.where(range.accepts).length;

    // 제목 아래 한 줄. 고른 게 없으면 안내, 시작만 골랐으면 끝을 고르라고,
    // 다 골랐으면 그 기간을 되비춰 준다.
    final String subtitle;
    if (range == null) {
      subtitle = HomeStrings.dateSheetHint;
    } else if (_end == null) {
      subtitle = '${range.label} · ${HomeStrings.dateSheetPickEnd}';
    } else {
      subtitle = range.label;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: HomeMetrics.sheetHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(HomeStrings.dateSheetTitle, style: textTheme.titleMedium),
              const SizedBox(height: HomeMetrics.sheetTitleGap),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: HomeMetrics.sheetSectionGap),
        _PresetChips(
          selected: range,
          today: widget.today,
          onSelected: _pickPreset,
        ),
        const SizedBox(height: HomeMetrics.sheetSectionGap),
        Expanded(
          child: RangeCalendar(
            span: _span,
            today: widget.today,
            start: _start,
            end: _end,
            countByDay: _countByDay,
            onDayPressed: _pressDay,
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.sheetHorizontalPadding,
            ),
          ),
        ),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.sheetHorizontalPadding,
              vertical: HomeMetrics.sheetActionVerticalPadding,
            ),
            child: Row(
              children: [
                TextButton(
                  onPressed: range == null ? null : _reset,
                  child: const Text(HomeStrings.dateSheetReset),
                ),
                const SizedBox(width: HomeMetrics.sheetActionGap),
                Expanded(
                  child: AppActionButton(
                    label: range == null
                        ? HomeStrings.dateSheetApplyAll
                        : HomeStrings.dateSheetApply(matchCount),
                    onPressed: _apply,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 손잡이. 이 시트가 끌어 내려 닫히는 것임을 알린다.
class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: HomeMetrics.sheetHandleWidth,
        height: HomeMetrics.sheetHandleHeight,
        margin: const EdgeInsets.only(
          top: HomeMetrics.sheetHandleTopGap,
          bottom: HomeMetrics.sheetSectionGap,
        ),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(
            HomeMetrics.sheetHandleHeight / 2,
          ),
        ),
      ),
    );
  }
}

/// 빠른 선택 칩 한 줄. 지금 고른 기간과 같은 프리셋만 켜진다 — 달력에서 손으로
/// 고른 기간은 어느 칩에도 해당하지 않는다.
class _PresetChips extends StatelessWidget {
  const _PresetChips({
    required this.selected,
    required this.today,
    required this.onSelected,
  });

  final ShowDateRange? selected;
  final DateTime today;
  final ValueChanged<ShowDatePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeMetrics.presetChipHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: HomeMetrics.sheetHorizontalPadding,
        ),
        children: [
          for (final preset in ShowDatePreset.values) ...[
            if (preset != ShowDatePreset.values.first)
              const SizedBox(width: HomeMetrics.presetChipGap),
            _PresetChip(
              label: preset.label,
              selected: preset.rangeFrom(today) == selected,
              onTap: () => onSelected(preset),
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 켜진 칩은 진한 브랜드색 위 흰 굵은 글자. 찜 화면의 필터 칩과 같은 규칙이다.
    final background = selected ? AppColors.primaryPressed : AppColors.surface;
    final foreground = selected ? AppColors.onPrimary : AppColors.textPrimary;
    final radius = BorderRadius.circular(HomeMetrics.presetChipHeight / 2);

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.primaryPressed : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.presetChipHorizontalPadding,
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
