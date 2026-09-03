// 결제 화면 표시용 포맷터. 화면·위젯이 문자열 조립을 직접 하지 않게 모아 둔다.

/// 1000 단위 쉼표를 넣고 `원`을 붙인다. (예: 186000 -> `186,000원`)
String formatWon(int amount) => '${_groupDigits(amount)}원';

String _groupDigits(int value) {
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
String formatPerformedAt(DateTime at, {String separator = '.'}) {
  final date = [
    at.year.toString().padLeft(4, '0'),
    at.month.toString().padLeft(2, '0'),
    at.day.toString().padLeft(2, '0'),
  ].join(separator);
  return '$date ${_twoDigits(at.hour)}:${_twoDigits(at.minute)}';
}

/// 남은 시간을 `mm:ss`로 바꾼다. 음수는 0으로 본다.
String formatCountdown(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  return '${_twoDigits(clamped.inMinutes)}:${_twoDigits(clamped.inSeconds % 60)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
