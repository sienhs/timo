/// 알림함이 시각을 "20분 전" 처럼 보여 주기 위한 표기. 1분 미만은 방금, 1시간
/// 미만은 N분 전, 24시간 미만은 N시간 전이고, 그 뒤로는 달력 날짜로 세어 어제 →
/// N일 전(5일까지) → "9월 18일" 이다. 23시간 전이어도 달력상 오늘이면 "23시간 전"
/// 이고, 날짜 경계는 기기 시간대를 따른다.
library;

/// [at] 이 [now] 로부터 얼마나 지났는지.
///
/// [now] 는 테스트에서 시계를 고정하려고 받는다. 화면에서는 넘기지 않는다.
String relativeTime(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final elapsed = current.difference(at);

  // 기기 시계가 서버보다 뒤처져 있으면 알림이 미래에 온 것으로 계산된다.
  // "-3분 전" 같은 문구를 내보내는 대신 방금으로 본다.
  if (elapsed.isNegative || elapsed.inMinutes < 1) return '방금';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
  if (elapsed.inHours < 24) return '${elapsed.inHours}시간 전';

  final days = _calendarDaysBetween(at, current);
  if (days <= 1) return '어제';
  if (days <= 5) return '$days일 전';
  return '${at.month}월 ${at.day}일';
}

/// 시각은 버리고 달력 날짜끼리 뺀 일수. 어제는 1, 그제는 2다.
int _calendarDaysBetween(DateTime from, DateTime to) {
  final fromDate = DateTime(from.year, from.month, from.day);
  final toDate = DateTime(to.year, to.month, to.day);
  return toDate.difference(fromDate).inDays;
}
