import '../constants.dart';
import 'concert_summary.dart';

/// 목록 위 칩으로 고르는 범위.
///
/// 라벨과 판정을 한곳에 둔다. 둘이 떨어져 있으면 '예정 공연' 칩이 지난 공연까지
/// 세는 식으로 어긋나고, 어긋난 걸 화면을 켜 봐야 안다.
///
/// '지난 공연' 칩은 두지 않는다. 게이트에서 지난 공연을 고르는 건 날짜가 잘못
/// 등록된 공연을 급히 검표해야 할 때뿐이라, 칩 하나를 상시로 내주기엔 드물다.
/// 그런 공연은 [all] 에 그대로 남아 있고 정렬에서 맨 아래로 간다
/// ([ConcertSummary.sortedForGate]).
enum ConcertFilter {
  all(ConcertStrings.filterAll),
  today(ConcertStrings.filterToday),
  upcoming(ConcertStrings.filterUpcoming);

  const ConcertFilter(this.label);

  /// 칩에 적히는 이름. 개수는 화면이 붙인다.
  final String label;

  /// 이 공연이 이 범위에 드는지.
  bool matches(ConcertSummary concert, DateTime now) => switch (this) {
    ConcertFilter.all => true,
    ConcertFilter.today => concert.isOn(now),
    ConcertFilter.upcoming => concert.isUpcoming(now),
  };

  /// 범위별 개수. 칩에 붙일 숫자다.
  ///
  /// 고른 범위가 아니라 **받아 온 목록 전체**로 센다 — 칩의 숫자는 "거기에 몇
  /// 개가 있는지" 라서, 고른 범위에 따라 다른 칩의 숫자가 바뀌면 안 된다.
  static Map<ConcertFilter, int> countsOf(
    Iterable<ConcertSummary> concerts, {
    required DateTime now,
  }) => {
    for (final filter in values)
      filter: concerts.where((c) => filter.matches(c, now)).length,
  };
}
