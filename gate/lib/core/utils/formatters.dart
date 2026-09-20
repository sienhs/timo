/// 날짜·시간 표시 형식. 화면·위젯이 문자열 조립을 직접 하지 않게 모아 둔다.
///
/// 팬 앱 `core/utils/formatters.dart` 에서 게이트가 쓰는 것만 가져왔다. 형식도
/// 같다 — 같은 공연을 두 앱이 다르게 적으면 운영자가 대조할 때 헷갈린다.
///
/// intl 패키지는 붙이지 않았다. 필요한 형태가 둘뿐이라 의존성을 늘릴 이유가 없다.
library;

/// 공연 일시. (예: `2026.11.04 (수) 18:00`)
String formatPerformedAt(DateTime at) =>
    '${formatDate(at)} (${_weekdayNames[at.weekday - 1]}) ${_twoDigits(at.hour)}:${_twoDigits(at.minute)}';

/// 날짜만. (예: `2026.11.04`)
String formatDate(DateTime at) => [
  at.year.toString().padLeft(4, '0'),
  _twoDigits(at.month),
  _twoDigits(at.day),
].join('.');

/// 공연 기간. 하루짜리면 일시 하나로, 여러 날이면 `시작 ~ 종료 날짜` 로 적는다.
///
/// 시작 시각을 살리는 이유: 게이트가 서는 날의 공연이 몇 시에 시작하는지가
/// 운영자에게 가장 쓸모 있는 정보다. 여러 날 공연이면 끝나는 날은 날짜만 있으면
/// 된다.
String formatPeriod(DateTime start, DateTime? end) {
  if (end == null || isSameDay(start, end)) return formatPerformedAt(start);
  return '${formatPerformedAt(start)} ~ ${formatDate(end)}';
}

/// 두 시각이 같은 날인지. 시·분은 보지 않는다.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

String _twoDigits(int value) => value.toString().padLeft(2, '0');
