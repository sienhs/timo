import '../constants.dart';

/// 지금 마켓이 열려 있는지와, 다음 경계까지 남은 시간.
///
/// **서버에 운영 시간 규칙이 없어 앱이 시계로 판정한다**
/// ([ResaleMetrics.marketOpensAtHour] 주석). 판정을 화면마다 하면 공연 목록은
/// 열렸다고 보고 매물 목록은 닫혔다고 보는 일이 생기므로 한 곳에 모은다.
///
/// 기준 시각을 인자로 받는다. 안에서 `DateTime.now()` 를 부르면 같은 화면의
/// 카운트다운과 열림 판정이 미세하게 어긋나고, 테스트가 시각을 고정할 수 없다.
class MarketHours {
  const MarketHours._(this._now, this._openedAt);

  /// [now] 시점의 운영 상태.
  factory MarketHours.at(DateTime now) {
    final todayOpen = _openOf(now);
    // 자정을 넘겨 열려 있는 창(예: 20:00 + 6시간)도 있으므로 어제 창까지 본다.
    final yesterdayOpen = todayOpen.subtract(const Duration(days: 1));
    for (final openedAt in [todayOpen, yesterdayOpen]) {
      if (!now.isBefore(openedAt) &&
          now.isBefore(openedAt.add(ResaleMetrics.marketOpenDuration))) {
        return MarketHours._(now, openedAt);
      }
    }
    return MarketHours._(now, null);
  }

  final DateTime _now;

  /// 지금 열려 있는 창이 열린 시각. 닫혀 있으면 null 이다.
  final DateTime? _openedAt;

  bool get isOpen => _openedAt != null;

  /// 열려 있으면 닫히는 시각, 닫혀 있으면 다음에 열리는 시각.
  ///
  /// 열림·닫힘에서 세는 대상이 다를 뿐 화면이 하는 일은 "이 시각까지 남은 시간을
  /// 보여 준다" 하나라 한 값으로 준다.
  DateTime get nextBoundary {
    final openedAt = _openedAt;
    if (openedAt != null) {
      return openedAt.add(ResaleMetrics.marketOpenDuration);
    }
    final todayOpen = _openOf(_now);
    return todayOpen.isAfter(_now)
        ? todayOpen
        : todayOpen.add(const Duration(days: 1));
  }

  /// 다음 경계까지 남은 시간. 이미 지났으면 0 이다.
  Duration get remaining {
    final left = nextBoundary.difference(_now);
    return left.isNegative ? Duration.zero : left;
  }

  /// 여는 시각을 `20:00` 처럼 적는다. 닫힘 화면의 안내 문구가 쓴다.
  static String get opensAtLabel =>
      '${ResaleMetrics.marketOpensAtHour.toString().padLeft(2, '0')}:00';

  static DateTime _openOf(DateTime day) =>
      DateTime(day.year, day.month, day.day, ResaleMetrics.marketOpensAtHour);
}
