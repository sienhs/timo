import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 공연 목록 한 줄. 백엔드 `ConcertSummaryResponseDto` 에서 게이트가 쓰는
/// 값만 담는다.
///
/// 장르·연령·조회수·예매 상태는 받아도 쓰지 않아 담지 않는다. 게이트 운영자가
/// 목록에서 하는 일은 "오늘 내가 서 있는 입구의 공연 찾기" 하나뿐이고, 그
/// 판단에 필요한 건 공연명·공연장·일시다.
@immutable
class ConcertSummary {
  const ConcertSummary({
    required this.id,
    required this.title,
    required this.venueName,
    required this.startDate,
    this.endDate,
    this.posterImageUrl,
  });

  /// 서버 응답 한 건에서 만든다. 날짜가 없거나 깨져 있으면 null 로 둔다 —
  /// 일시를 모르는 공연이라도 목록에서 골라 검표는 할 수 있어야 한다.
  factory ConcertSummary.fromJson(Map<String, dynamic> json) => ConcertSummary(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    venueName: json['venueName'] as String? ?? '',
    startDate: _dateOrNull(json['startDate']),
    endDate: _dateOrNull(json['endDate']),
    posterImageUrl: json['posterImageUrl'] as String?,
  );

  static DateTime? _dateOrNull(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  final int id;
  final String title;
  final String venueName;

  /// 공연 시작 일시. 모르면 null.
  final DateTime? startDate;

  /// 여러 날 하는 공연의 마지막 날. 하루짜리면 [startDate] 와 같은 날이다.
  final DateTime? endDate;

  /// 저장소 key 다. 그릴 때 `ApiClient.imageUrl` 로 주소를 만든다.
  final String? posterImageUrl;

  /// 목록 줄과 스캔 화면 헤더에 적는 일시 한 줄.
  String get whenLabel {
    final start = startDate;
    return start == null ? ConcertStrings.noDate : formatPeriod(start, endDate);
  }

  /// [now] 가 이 공연의 기간 안에 드는지. 하루짜리면 그날이면 참이다.
  ///
  /// 시작 시각이 아니라 **날짜**로 본다. 게이트는 공연 시작 두 시간 전부터
  /// 문을 열고, 그때도 이 공연은 "오늘" 이어야 한다.
  bool isOn(DateTime now) {
    final start = startDate;
    if (start == null) return false;
    if (isSameDay(start, now)) return true;
    final end = endDate;
    if (end == null) return false;
    return now.isAfter(start) && !now.isAfter(_endOfDay(end));
  }

  /// 아직 열리지 않은 공연인지. 오늘 하는 공연은 여기 들지 않는다.
  bool isUpcoming(DateTime now) {
    final start = startDate;
    return start != null && !isOn(now) && start.isAfter(now);
  }

  /// 지금 팬 앱이 이 공연의 입장 QR 을 받을 수 있는 시간대인지.
  ///
  /// [isOn] 과 달리 **시각**으로 본다. 오늘 하는 공연이어도 문 열기 전(시작
  /// 두 시간 전)에는 거짓이다. 판정 창은 백엔드가 QR 을 발급해 주는 구간과
  /// 같아야 한다 — [ConcertMetrics.entryOpensBefore] 주석 참고.
  bool isEntryOpen(DateTime now) {
    final start = startDate;
    if (start == null) return false;
    return !now.isBefore(start.subtract(ConcertMetrics.entryOpensBefore)) &&
        !now.isAfter(start.add(ConcertMetrics.entryClosesAfter));
  }

  /// 게이트가 보기 좋은 순서로 다시 늘어놓는다. 원본은 건드리지 않는다.
  ///
  /// 오늘 하는 공연 → 앞으로 할 공연(가까운 순) → 지나간 공연(최근 순) →
  /// 일시를 모르는 공연. 서버는 등록 순서(최근 등록순)로 주는데, 게이트에서
  /// 찾는 건 거의 항상 오늘 공연이라 그대로 두면 매번 스크롤해야 한다.
  ///
  /// 지나간 공연도 지우지 않고 맨 아래에 남긴다. 날짜가 하루 어긋나게 등록된
  /// 공연이 목록에서 통째로 사라지면 게이트가 아무것도 못 한다.
  static List<ConcertSummary> sortedForGate(
    Iterable<ConcertSummary> concerts, {
    required DateTime now,
  }) {
    final sorted = concerts.toList();
    sorted.sort((a, b) {
      final rankGap = a._rank(now) - b._rank(now);
      if (rankGap != 0) return rankGap;
      final aStart = a.startDate;
      final bStart = b.startDate;
      if (aStart == null || bStart == null) return a.title.compareTo(b.title);
      // 지나간 공연은 최근 것이 위로, 나머지는 가까운 것이 위로 온다.
      return a._rank(now) == _rankPast
          ? bStart.compareTo(aStart)
          : aStart.compareTo(bStart);
    });
    return sorted;
  }

  static const _rankToday = 0;
  static const _rankUpcoming = 1;
  static const _rankPast = 2;
  static const _rankUnknown = 3;

  int _rank(DateTime now) {
    final start = startDate;
    if (start == null) return _rankUnknown;
    if (isOn(now)) return _rankToday;
    return start.isAfter(now) ? _rankUpcoming : _rankPast;
  }

  static DateTime _endOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day, 23, 59, 59);
}
