/// 서버가 주는 공연 일시(`LocalDateTime`)를 화면 문구로 바꾼다.
///
/// 카탈로그(`/collectibles/concerts`)와 소장품의 공연 스냅샷이 같은 모양으로
/// 오고, 티켓 뒷면에는 같은 글자로 찍혀야 한다. 한 곳에서만 만든다.
class ConcertDateTime {
  ConcertDateTime._();

  /// `2026-09-26T19:00:00` → `2026.09.26`. 읽을 수 없으면 빈 문자열.
  static String date(String? value) {
    final at = _parse(value);
    return at == null ? '' : '${at.year}.${_two(at.month)}.${_two(at.day)}';
  }

  /// `2026-09-26T19:00:00` → `19:00`. 읽을 수 없으면 null — 시각이 없는 줄은
  /// 시각 칸 자체를 내지 않는다.
  static String? time(String? value) {
    final at = _parse(value);
    return at == null ? null : '${_two(at.hour)}:${_two(at.minute)}';
  }

  static DateTime? _parse(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  static String _two(int value) => value.toString().padLeft(2, '0');
}
