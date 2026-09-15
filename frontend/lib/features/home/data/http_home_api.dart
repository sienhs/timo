import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import '../models/show_summary.dart';
import '../models/trending_keyword.dart';
import 'home_api.dart';
import 'mock_home_data.dart';

/// 백엔드 공연 목록 API 에 실제로 요청하는 [HomeApi].
///
/// 지금은 프론트 연동용 스텁(`/api/v0`)에 붙어 있다. 스텁은 실제 컨트롤러와
/// 같은 `ConcertApi` 인터페이스를 구현하므로 요청·응답 모양이 v1 과 같다.
/// 실제 API 가 열리면 [basePath] 의 버전만 `v1` 으로 바꾼다.
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
/// [clock] 도 테스트용이다 — 목업 인기 검색어의 집계 시각을 고정한다.
class HttpHomeApi implements HomeApi {
  HttpHomeApi({Dio? dio, this.clock = DateTime.now})
    : _dio = dio ?? ApiClient.dio;

  static const basePath = '/api/v0/concerts';

  /// MVP 는 콘서트만 다룬다. 세 요청 모두 이 장르로 좁힌다.
  static const _genre = 'CONCERT';

  /// 정렬 이름. 백엔드 `ConcertSortType` 의 상수명과 같다.
  static const _sortOpenSoon = 'OPEN_SOON';
  static const _sortPopular = 'POPULAR';

  final Dio _dio;
  final DateTime Function() clock;

  @override
  Future<List<ShowSummary>> fetchTicketOpenSoon() => _list({
    'genre': _genre,
    // 정렬은 이미 오픈한 공연을 걸러 주지 않는다. 상태로 직접 거른다.
    'status': ShowSummary.upcomingStatus,
    'sort': _sortOpenSoon,
    'size': HomeMetrics.showRowSize,
  });

  @override
  Future<List<ShowSummary>> fetchPopular() => _list({
    'genre': _genre,
    'sort': _sortPopular,
    'size': HomeMetrics.showRowSize,
  });

  /// 상태로 좁히지 않는다. 서버의 `status` 는 값 하나만 받아 "오픈 예정 또는
  /// 예매중" 을 한 요청으로 물을 수 없다. 화면이 받은 뒤 거른다.
  @override
  Future<List<ShowSummary>> search(String keyword) => _list({
    'genre': _genre,
    'keyword': keyword,
    'size': HomeMetrics.searchPageSize,
  });

  /// 아티스트 API 는 백엔드에 아직 없다(엔티티만 있다). 그때까지 목업을
  /// 돌려준다. API 가 생기면 이 본문만 `GET` 으로 바꾸고 [MockHomeData] 의
  /// 해당 항목을 지운다 — 시그니처가 같으니 화면과 [HomeApi] 는 손대지 않는다.
  /// 아래 세 메서드도 같은 사정이다.
  @override
  Future<List<ArtistSummary>> fetchPopularArtists() =>
      Future.value(MockHomeData.artists);

  @override
  Future<List<ArtistSummary>> fetchRecommendedArtists() =>
      Future.value(MockHomeData.recommendedArtists);

  @override
  Future<TrendingKeywords> fetchTrendingKeywords() => Future.value(
    TrendingKeywords(
      asOf: MockHomeData.trendingAsOf(clock()),
      items: MockHomeData.trendingKeywords,
    ),
  );

  @override
  Future<List<ArtistSummary>> searchArtists(String keyword) =>
      Future.value(MockHomeData.matchArtists(keyword));

  /// 목록 응답은 Spring 의 `PagedModel` 이라 공연 배열이 `content` 안에 있다.
  /// 홈은 첫 페이지만 보므로 `page` 정보는 읽지 않는다.
  Future<List<ShowSummary>> _list(Map<String, Object> query) async {
    final response = await _guard(
      () => _dio.get<dynamic>(basePath, queryParameters: query),
    );
    final content = _body(response)['content'];
    if (content is! List) throw _unreadable(response);
    return content
        .whereType<Map<String, dynamic>>()
        .map(ShowSummary.fromJson)
        .toList();
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  ///
  /// `HttpAuthApi` 와 같다. 세 번째 API 가 같은 이유로 필요해지면 그때
  /// `core/network` 로 올린다.
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
