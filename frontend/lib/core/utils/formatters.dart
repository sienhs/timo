/// 금액·날짜·시간·전화번호 표시 포맷. 화면·위젯이 문자열 조립을 직접 하지
/// 않게 모아 둔다. `extension on int` 이 아니라 함수로 두는 것은 좌석 번호처럼
/// 금액이 아닌 정수에도 `.won` 이 붙어 오타가 컴파일을 통과하기 때문이다.
library;

/// 1000 단위 쉼표를 넣고 `원`을 붙인다. (예: 186000 -> `186,000원`)
String formatWon(int amount) => '${formatThousands(amount)}원';

/// 코인 단위. 앱 안에서 코인은 '버섯', 단위는 `MSR` 하나로 부른다. 단위를 바꿀
/// 일이 생기면 여기만 고친다.
const coinUnit = 'MSR';

/// 1000 단위 쉼표를 넣고 코인 단위를 붙인다. (예: 198000 -> `198,000 MSR`)
/// 티켓 값·환불 금액처럼 결제와 오가는 돈은 원이 아니라 [coinUnit] 으로 적는다.
String formatMsr(int amount) => '${formatThousands(amount)} $coinUnit';

/// 1000 단위 쉼표만 넣는다. (예: 186000 -> `186,000`)
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value.isNegative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    final isGroupBoundary = i > 0 && (digits.length - i) % 3 == 0;
    if (isGroupBoundary) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 공연 일시를 표시 형식으로 바꾼다. (예: `2026.11.04 18:00`)
/// 구분자는 `.` 하나로 고정한다.
String formatPerformedAt(DateTime at) =>
    '${_formatDate(at)} ${_formatTime(at)}';

/// 요일까지 붙인 형식. (예: `2026.11.04 (수) 18:00`)
/// 좌석 선택 화면의 공연 정보 바처럼 날짜 감각이 필요한 곳에 쓴다.
String formatPerformedAtWithWeekday(DateTime at) =>
    '${_formatDate(at)} (${_weekdayNames[at.weekday - 1]}) ${_formatTime(at)}';

/// 남은 시간을 `mm:ss` 로 바꾼다. 음수는 0으로 본다. (예: `04:32`)
String formatCountdown(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  return '${_twoDigits(clamped.inMinutes)}:${_twoDigits(clamped.inSeconds % 60)}';
}

/// 전화번호 숫자열에 하이픈을 넣는다. (예: `01012345678` -> `010-1234-5678`)
/// 입력 도중에도 쓰므로 자릿수가 모자라면 있는 만큼만 끊고, 하이픈이 섞여
/// 들어와도 걷어내고 다시 넣어 여러 번 통과시켜도 결과가 같다.
String formatPhoneNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 3) return digits;
  if (digits.length <= 7) {
    return '${digits.substring(0, 3)}-${digits.substring(3)}';
  }
  return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-'
      '${digits.substring(7)}';
}

const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

String _formatDate(DateTime at) => [
  at.year.toString().padLeft(4, '0'),
  _twoDigits(at.month),
  _twoDigits(at.day),
].join('.');

String _formatTime(DateTime at) =>
    '${_twoDigits(at.hour)}:${_twoDigits(at.minute)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// 공연 기간을 표시 형식으로 바꾼다. 하루 공연은 날짜 하나(`2026.11.15`), 기간
/// 공연은 물결로 잇고 끝 연도는 시작과 같으면 생략한다(`2026.07.05 ~ 07.07`).
/// 서버는 하루 공연에도 `endDate` 를 시작일과 같게 채워 주므로 끝이 없을 때만이
/// 아니라 시작과 같은 날일 때도 날짜 하나로 적는다.
String formatShowPeriod(DateTime startAt, [DateTime? endAt]) {
  if (endAt == null || _isSameDay(startAt, endAt)) return _formatDate(startAt);
  final end = startAt.year == endAt.year
      ? '${_twoDigits(endAt.month)}.${_twoDigits(endAt.day)}'
      : _formatDate(endAt);
  return '${_formatDate(startAt)} ~ $end';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 연도를 뺀 월·일과 요일. (예: `10.25 (금)`)
/// 올해 안의 가까운 일정처럼 연도가 자명한 자리에 쓴다.
String formatMonthDayWithWeekday(DateTime at) =>
    '${_twoDigits(at.month)}.${_twoDigits(at.day)} '
    '(${_weekdayNames[at.weekday - 1]})';

/// 연도를 뺀 월·일. (예: `10.05`) 달력에서 고른 기간처럼 연도가 자명하고
/// 요일까지는 필요 없는 자리에 쓴다.
String formatMonthDay(DateTime at) =>
    '${_twoDigits(at.month)}.${_twoDigits(at.day)}';

/// 시:분만. (예: `14:00`) 날짜가 문맥으로 이미 정해진 자리에 쓴다.
String formatClock(DateTime at) => _formatTime(at);

/// 남은 시간을 `hh:mm:ss` 로 바꾼다. 음수는 0으로 본다. (예: `00:23:14`)
/// [formatCountdown] 과 합쳐 시간 자리를 조건부로 빼면 자릿수가 오락가락해서
/// 나눠 둔다. 하루가 넘으면 시간 자리가 24 를 넘으니 그땐 오픈 일시를 보여준다.
String formatCountdownWithHours(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  return [
    _twoDigits(clamped.inHours),
    _twoDigits(clamped.inMinutes % 60),
    _twoDigits(clamped.inSeconds % 60),
  ].join(':');
}

/// 부호를 항상 붙인 천 단위 금액. (예: 150000 -> `+150,000`, -176000 -> `-176,000`)
/// 거래 내역처럼 증감이 한 목록에 섞이는 자리에 쓴다. 0 은 부호 없이 `0` 이다.
String formatSignedThousands(int value) =>
    value > 0 ? '+${formatThousands(value)}' : formatThousands(value);

/// 연도를 뺀 월·일과 시:분. (예: `09.12 19:42`)
/// 거래 내역처럼 최근 것이 줄지어 있어 연도가 자명한 자리에 쓴다.
String formatMonthDayClock(DateTime at) =>
    '${_twoDigits(at.month)}.${_twoDigits(at.day)} ${_formatTime(at)}';
