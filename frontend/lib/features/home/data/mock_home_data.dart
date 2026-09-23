import '../models/artist_summary.dart';
import '../models/trending_keyword.dart';

/// 홈·검색 섹션의 목업 데이터. 테스트용 `MockHomeApi` 만 쓴다.
class MockHomeData {
  MockHomeData._();

  /// 홈 인기 아티스트(테스트용). 마지막 '더보기' 칸은 데이터가 아니라 화면이 그린다.
  static const artists = <ArtistSummary>[
    ArtistSummary(name: '김준수'),
    ArtistSummary(name: '옥주현'),
    ArtistSummary(name: '검정치마'),
    ArtistSummary(name: '정명훈'),
    ArtistSummary(name: '아이유'),
    ArtistSummary(name: '박보검'),
    ArtistSummary(name: '페기구'),
  ];

  /// 검색 화면의 추천 검색어(테스트용). 한 줄 칸 수만큼 네 명이다.
  static const recommendedArtists = <ArtistSummary>[
    ArtistSummary(name: '리센느'),
    ArtistSummary(name: '뷔'),
    ArtistSummary(name: '아이유'),
    ArtistSummary(name: '블랙핑크'),
  ];

  /// 관련 아티스트 검색이 뒤지는 전체 풀. 홈과 추천에 나온 이름을 합친 것이다.
  static final allArtists = <ArtistSummary>[
    ...artists,
    ...recommendedArtists.where(
      (artist) => artists.every((known) => known.name != artist.name),
    ),
  ];

  /// 실시간 인기 검색어(테스트용). 순위와 등락이 섞여 있다.
  static const trendingKeywords = <TrendingKeyword>[
    TrendingKeyword(rank: 1, keyword: 'RESCENE', trend: KeywordTrend.up),
    TrendingKeyword(rank: 2, keyword: '제니'),
    TrendingKeyword(rank: 3, keyword: '블랙핑크', trend: KeywordTrend.up),
    TrendingKeyword(rank: 4, keyword: 'KiiiKiii', trend: KeywordTrend.down),
    TrendingKeyword(rank: 5, keyword: 'CORTIS'),
    TrendingKeyword(rank: 6, keyword: '아이오아이', trend: KeywordTrend.down),
    TrendingKeyword(rank: 7, keyword: 'aespa'),
    TrendingKeyword(rank: 8, keyword: 'ILLIT'),
    TrendingKeyword(rank: 9, keyword: '하츠투하츠'),
    TrendingKeyword(rank: 10, keyword: '레드벨벳', trend: KeywordTrend.up),
  ];

  /// 인기 검색어 집계 시각(테스트용). 정시마다 집계하는 서버를 흉내 내 지금
  /// 시각을 정시로 내린다 — 고정 날짜로 두면 화면에 늘 지난 날짜가 찍힌다.
  static DateTime trendingAsOf(DateTime now) =>
      DateTime(now.year, now.month, now.day, now.hour);

  /// 이름에 [keyword] 가 들어가는 아티스트. 대소문자는 가리지 않는다.
  static List<ArtistSummary> matchArtists(String keyword) {
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return allArtists
        .where((artist) => artist.name.toLowerCase().contains(needle))
        .toList();
  }
}
