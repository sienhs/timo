import '../constants.dart';
import '../models/artist_summary.dart';
import '../models/show_summary.dart';
import '../models/trending_keyword.dart';
import 'home_api.dart';
import 'mock_home_data.dart';

/// 서버 없이 쓰는 가짜 [HomeApi]. 화면 테스트가 쓴다. 응답마다 [latency] 만큼
/// 기다려 로딩 상태가 보이게 한다(기다릴 필요가 없으면 `Duration.zero`).
/// 티켓 오픈 일시는 실행 시각 기준 상대값이라 세 가지 뱃지 형태가 늘 보인다.
class MockHomeApi implements HomeApi {
  const MockHomeApi({
    this.latency = HomeMetrics.mockLatency,
    this.clock = DateTime.now,
  });

  final Duration latency;

  /// 인기 검색어 집계 시각의 기준. 테스트가 고정한다.
  final DateTime Function() clock;

  /// 지연이 0 이면 타이머를 만들지 않는다. 0 짜리 타이머도 타이머라, 프레임을
  /// 한 번만 그리는 위젯 테스트가 끝날 때 "아직 남은 타이머" 로 잡힌다.
  Future<void> _respond() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<List<ShowSummary>> fetchTicketOpenSoon() async {
    await _respond();
    return ticketOpenSoon;
  }

  @override
  Future<List<ShowSummary>> fetchPopular() async {
    await _respond();
    return popular;
  }

  @override
  Future<List<ShowSummary>> fetchTicketOpenAll() async {
    await _respond();
    return ticketOpenSoon;
  }

  @override
  Future<List<ShowSummary>> fetchAllShows() async {
    await _respond();
    return all;
  }

  @override
  Future<List<ShowSummary>> search(String keyword) async {
    await _respond();
    final needle = keyword.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return all
        .where((show) => show.title.toLowerCase().contains(needle))
        .toList();
  }

  @override
  Future<List<ArtistSummary>> fetchPopularArtists() async {
    await _respond();
    return MockHomeData.artists;
  }

  @override
  Future<List<ArtistSummary>> fetchRecommendedArtists() async {
    await _respond();
    return MockHomeData.recommendedArtists;
  }

  @override
  Future<TrendingKeywords> fetchTrendingKeywords() async {
    await _respond();
    return TrendingKeywords(
      asOf: MockHomeData.trendingAsOf(clock()),
      items: MockHomeData.trendingKeywords,
    );
  }

  @override
  Future<List<ArtistSummary>> searchArtists(String keyword) async {
    await _respond();
    return MockHomeData.matchArtists(keyword);
  }

  /// 오늘 자정. 오픈 일시를 여기서 더해 만든다.
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 당일 오픈을 흉내 낼 시각. 지금으로부터 두 시간 뒤다. 오늘의 고정 시각으로
  /// 두면 그 시각을 넘긴 뒤로는 [ShowSummary.opensAfter] 가 걸러 버려 밤에 돌린
  /// 테스트만 깨진다.
  static DateTime get _soon => DateTime.now().add(const Duration(hours: 2));

  /// 오픈이 빠른 순. 이미 오픈한 공연은 없다 — 서버도 `SCHEDULED` 만 준다.
  static final ticketOpenSoon = <ShowSummary>[blackSkirt, remind, bigbang];

  /// 목록 순서가 곧 순위다(1위부터).
  static final popular = <ShowSummary>[remind, bigbang, iu, xia, peggyGou];

  /// 검색이 뒤지는 전체. 서버처럼 예매 상태로 거르지 않아 종료된 공연
  /// ([peggyGou])도 들어 있다.
  static final all = <ShowSummary>[
    iu,
    remind,
    bigbang,
    blackSkirt,
    xia,
    peggyGou,
  ];

  /// 이미 오픈한 공연. 오픈 뱃지가 없다.
  static final iu = ShowSummary(
    id: 1,
    title: '2026 아이유 콘서트',
    venueName: '고척스카이돔',
    status: ShowSummary.onSaleStatus,
    startAt: DateTime(2026, 11, 1),
    endAt: DateTime(2026, 12, 31),
  );

  static final remind = ShowSummary(
    id: 2,
    title: 'REMIND : 리센느',
    venueName: '올림픽공원 체조경기장',
    status: ShowSummary.upcomingStatus,
    startAt: DateTime(2026, 7, 5),
    endAt: DateTime(2026, 7, 7),
    ticketOpenAt: _today.add(const Duration(days: 5, hours: 19)),
  );

  static final bigbang = ShowSummary(
    id: 3,
    title: '2026 BIGBANG',
    venueName: '고양종합운동장',
    status: ShowSummary.upcomingStatus,
    startAt: DateTime(2026, 11, 15),
    // 한 달 뒤 이후 — 날짜를 그대로 읽어 주는 뱃지가 여기서 나온다.
    ticketOpenAt: _today.add(const Duration(days: 48, hours: 14)),
  );

  static final blackSkirt = ShowSummary(
    id: 4,
    title: '검정치마 단독공연 : 401',
    venueName: '무신사 개러지',
    status: ShowSummary.upcomingStatus,
    startAt: DateTime(2026, 9, 20),
    // 곧 오픈 — `오늘 HH시 MM분 오픈` 뱃지가 여기서 나온다.
    ticketOpenAt: _soon,
  );

  static final xia = ShowSummary(
    id: 5,
    title: '2026 김준수 콘서트 : XIGNATURE',
    venueName: '올림픽공원 핸드볼경기장',
    status: ShowSummary.onSaleStatus,
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 9, 3),
  );

  /// 이미 끝난 공연. 검색에는 잡히지만 "오픈 예정 / 예매중" 섹션에는 안 나온다.
  static final peggyGou = ShowSummary(
    id: 6,
    title: '페기구 THE LOUD SHOW',
    venueName: '잠실실내체육관',
    status: ShowSummary.closedStatus,
    startAt: DateTime(2026, 8, 15),
  );

}
