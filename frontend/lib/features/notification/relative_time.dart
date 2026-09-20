/// 알림함이 시각을 "20분 전" 처럼 보여 주기 위한 표기.
///
/// 며칠까지 상대로 쓰고 그 뒤로는 날짜로 넘어간다.
///
/// ```
/// 1분 미만       방금
/// 1시간 미만     N분 전
/// 24시간 미만    N시간 전
/// 하루 건너뜀    어제
/// 2~5일         N일 전
/// 6일 이상       9월 18일
/// ```
///
/// **"어제" 부터는 지난 시간이 아니라 날짜로 센다.** 23시간 전이어도 달력으로
/// 오늘이면 "23시간 전" 이고, 25시간 전이면 "어제" 다. 사람이 날짜를 그렇게 세기
/// 때문이다.
///
/// 날짜 경계는 **기기 시간대**를 따른다. 서버가 시각에 시간대를 붙여 주고 모델이
/// 기기 시간대로 옮겨 두므로, 기기가 어느 시간대로 맞춰져 있든 그 기준의 '오늘'과
/// 맞는다.
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
