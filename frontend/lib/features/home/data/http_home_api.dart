import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import '../models/show_summary.dart';
import '../models/trending_keyword.dart';
import 'home_api.dart';

/// 백엔드 공연 목록·아티스트 목록 API 에 실제로 요청하는 [HomeApi]. 서버 주소·
/// 로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은 [ApiException]
/// 이 맡는다. [dio] 와 [clock] 은 테스트용이라 앱에서는 넘기지 않는다.
class HttpHomeApi implements HomeApi {
  HttpHomeApi({Dio? dio, this.clock = DateTime.now})
    : _dio = dio ?? ApiClient.dio;

  static const concertsPath = '/api/v1/concerts';
  static const artistsPath = '/api/v1/artists';

  /// MVP 는 콘서트만 다룬다. 공연 요청 셋 모두 이 장르로 좁힌다.
  static const _genre = 'CONCERT';

  /// 정렬 이름. 백엔드 `ConcertSortType` 의 상수명과 같다.
  static const _sortOpenSoon = 'OPEN_SOON';
  static const _sortPopular = 'POPULAR';

  /// 아티스트 정렬 이름. 백엔드 `ArtistSortType` 의 상수명과 같다.
  static const _artistSortLatest = 'LATEST';

  final Dio _dio;
  final DateTime Function() clock;

  /// 직전 인기 검색어 순서. 다음 조회의 등락을 이것과 비교해 매긴다. 서버에
  /// 집계 이력이 없어 앱이 켜져 있는 동안만 기억한다 — 첫 조회는 전부 보합이다.
  List<String> _lastTrending = const [];

  @override
  Future<List<ShowSummary>> fetchTicketOpenSoon() => _shows({
    'genre': _genre,
    // 정렬은 이미 오픈한 공연을 걸러 주지 않는다. 상태로 직접 거른다.
    'status': ShowSummary.upcomingStatus,
    'sort': _sortOpenSoon,
    'size': HomeMetrics.showRowSize,
  });

  @override
  Future<List<ShowSummary>> fetchPopular() => _shows({
    'genre': _genre,
    'sort': _sortPopular,
    'size': HomeMetrics.showRowSize,
  });

  /// 홈의 한 줄과 같은 조건이되 목록 화면이 쓸 만큼 받아 온다.
  @override
  Future<List<ShowSummary>> fetchTicketOpenAll() => _shows({
    'genre': _genre,
    'status': ShowSummary.upcomingStatus,
    'sort': _sortOpenSoon,
    'size': HomeMetrics.showListPageSize,
  });

  /// 상태로 좁히지 않는다. `모두 보기` 탭이 종료된 공연까지 보여 주기 때문이다.
  /// 정렬은 인기순이다 — 인기 공연 줄의 더보기로 들어오는 자리라 그 줄의
  /// 순서가 이어져야 같은 목록의 나머지로 읽힌다.
  @override
  Future<List<ShowSummary>> fetchAllShows() => _shows({
    'genre': _genre,
    'sort': _sortPopular,
    'size': HomeMetrics.showListPageSize,
  });

  /// 상태로 좁히지 않는다. 서버의 `status` 는 값 하나만 받아 "오픈 예정 또는
  /// 예매중" 을 한 요청으로 물을 수 없다. 화면이 받은 뒤 거른다.
  @override
  Future<List<ShowSummary>> search(String keyword) => _shows({
    'genre': _genre,
    'keyword': keyword,
    'size': HomeMetrics.searchPageSize,
  });

  /// 정렬은 보내지 않는다. 서버 기본값이 이름순이고, 관련 아티스트 한 줄에는
  /// 그 순서가 맞다.
  @override
  Future<List<ArtistSummary>> searchArtists(String keyword) =>
      _artists({'keyword': keyword, 'size': HomeMetrics.relatedArtistPageSize});

  /// 서버에 "인기" 순은 없다. 아티스트 목록 API 는 이름순·등록순만 주므로
  /// 백엔드와 합의해 당분간 최근 등록순을 그대로 인기로 보인다. 인기 집계가
  /// 생기면 정렬 이름만 바꾼다.
  @override
  Future<List<ArtistSummary>> fetchPopularArtists() => _artists({
    'sort': _artistSortLatest,
    'size': HomeMetrics.popularArtistGridSize,
  });

  /// 추천도 같은 사정이다. 최근 등록순 앞머리를 한 줄만 받는다.
  @override
  Future<List<ArtistSummary>> fetchRecommendedArtists() => _artists({
    'sort': _artistSortLatest,
    'size': HomeMetrics.recommendedArtistRowSize,
  });

  /// 인기 검색어는 서버에 집계 API 가 아직 없어 조회수 순 공연명 뒤에 최근
  /// 등록순 아티스트명을 붙여 순위를 매긴다. 기준 시각은 요청한 지금이고, 등락은
  /// 이 앱이 직전에 받은 순위와 비교한다. 집계 API 가 생기면 이 본문만 바꾼다.
  @override
  Future<TrendingKeywords> fetchTrendingKeywords() async {
    final [shows, artists] = await Future.wait<List<Object>>([
      _shows({
        'genre': _genre,
        'sort': _sortPopular,
        'size': HomeMetrics.trendingCount,
      }),
      _artists({'sort': _artistSortLatest, 'size': HomeMetrics.trendingCount}),
    ]);
    final trending = TrendingKeywords.ranked(
      asOf: clock(),
      limit: HomeMetrics.trendingCount,
      previous: _lastTrending,
      keywords: [
        for (final show in shows.cast<ShowSummary>()) show.title,
        for (final artist in artists.cast<ArtistSummary>()) artist.name,
      ],
    );
    _lastTrending = trending.keywords;
    return trending;
  }

  Future<List<ShowSummary>> _shows(Map<String, Object> query) =>
      _page(concertsPath, query, ShowSummary.fromJson);

  Future<List<ArtistSummary>> _artists(Map<String, Object> query) =>
      _page(artistsPath, query, ArtistSummary.fromJson);

  /// 목록 응답은 Spring 의 `PagedModel` 이라 배열이 `content` 안에 있다.
  /// 홈·검색은 첫 페이지만 보므로 `page` 정보는 읽지 않는다.
  Future<List<T>> _page<T>(
    String path,
    Map<String, Object> query,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final response = await _guard(
      () => _dio.get<dynamic>(path, queryParameters: query),
    );
    final content = _body(response)['content'];
    if (content is! List) throw _unreadable(response);
    return content.whereType<Map<String, dynamic>>().map(fromJson).toList();
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면(프록시가 HTML 을 준 경우 등) 화면용
  /// 예외로 바꿔서, 화면이 형 변환 오류 대신 안내 문구를 받게 한다.
  Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw _unreadable(response);
  }

  ApiException _unreadable(Response<dynamic> response) =>
      ApiException(HomeStrings.unreadableResponse, status: response.statusCode);
}
