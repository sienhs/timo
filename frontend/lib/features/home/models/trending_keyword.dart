/// 인기 검색어의 순위 변동. 전 집계와 비교한 방향만 안다 — 몇 계단인지는
/// 시안에도 없다.
enum KeywordTrend { up, down, steady }

/// 실시간 인기 검색어 한 줄.
class TrendingKeyword {
  const TrendingKeyword({
    required this.rank,
    required this.keyword,
    this.trend = KeywordTrend.steady,
  });

  /// 1부터. 목록 순서와 같지만, 화면이 인덱스에 1을 더해 계산하지 않도록
  /// 데이터가 직접 들고 있다.
  final int rank;
  final String keyword;
  final KeywordTrend trend;
}

/// 인기 검색어 목록과 그 집계 시각. 시각이 없으면 "실시간" 이라는 말을 믿을
/// 근거가 없어 둘을 한 덩이로 받는다.
class TrendingKeywords {
  const TrendingKeywords({required this.asOf, required this.items});

  /// 검색어 목록에 순위를 매겨 만든다. 앞에 올수록 상위이고, 같은 말이 두 번
  /// 오면 먼저 온 자리만 남긴다. [limit] 개까지만 담는다.
  ///
  /// 등락은 [previous](직전 순위의 검색어 순서)와 비교한다. 없거나 직전에
  /// 없던 말이면 보합이다.
  factory TrendingKeywords.ranked({
    required DateTime asOf,
    required Iterable<String> keywords,
    required int limit,
    List<String> previous = const [],
  }) {
    final unique = <String>{};
    final items = <TrendingKeyword>[];
    for (final keyword in keywords) {
      if (items.length >= limit) break;
      if (!unique.add(keyword)) continue;
      final rank = items.length + 1;
      items.add(
        TrendingKeyword(
          rank: rank,
          keyword: keyword,
          trend: _trendOf(rank, previous.indexOf(keyword) + 1),
        ),
      );
    }
    return TrendingKeywords(asOf: asOf, items: items);
  }

  /// [previousRank] 가 0 이면 직전 순위에 없던 말이다.
  static KeywordTrend _trendOf(int rank, int previousRank) {
    if (previousRank == 0 || previousRank == rank) return KeywordTrend.steady;
    return rank < previousRank ? KeywordTrend.up : KeywordTrend.down;
  }

  final DateTime asOf;
  final List<TrendingKeyword> items;

  /// 검색어만 순위순으로. 다음 집계의 등락 비교에 쓴다.
  List<String> get keywords => [for (final item in items) item.keyword];
}
