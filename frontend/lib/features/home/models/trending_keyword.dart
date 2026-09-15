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

  final DateTime asOf;
  final List<TrendingKeyword> items;
}
