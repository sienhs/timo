import '../models/artist_summary.dart';
import '../models/show_summary.dart';
import '../models/trending_keyword.dart';

/// 홈·검색 화면이 서버에 요청하는 일. 앱은 `HttpHomeApi`, 테스트는 `MockHomeApi` 를
/// 쓴다. 공연 셋과 아티스트 셋은 각각 서버 목록 API 하나를 조건만 달리 부른다.
/// 실패는 `ApiException` 으로 던지고, 빈 목록은 실패가 아니라 정상 결과다.
abstract class HomeApi {
  /// 예매 오픈이 가까운 순. 아직 오픈하지 않은 공연만 온다.
  Future<List<ShowSummary>> fetchTicketOpenSoon();

  /// 많이 본 순. 목록 순서가 곧 순위다.
  Future<List<ShowSummary>> fetchPopular();

  /// 오픈 예정 공연 전체. [fetchTicketOpenSoon] 과 조건은 같고 개수만 다르다 —
  /// 저쪽은 홈의 가로 한 줄, 이쪽은 더보기로 들어가는 목록 화면이다.
  Future<List<ShowSummary>> fetchTicketOpenAll();

  /// 공연 전체. 예매 상태로 거르지 않으므로 종료·취소된 공연도 온다 —
  /// 목록 화면의 `모두 보기` 탭이 그대로 보여 주고, `예매 가능` 탭이
  /// [ShowSummary.status] 로 거른다.
  Future<List<ShowSummary>> fetchAllShows();

  /// 공연명에 [keyword] 가 들어 있는 공연. 최근 등록순. 예매 상태로 거르지
  /// 않으므로 종료·취소 공연도 올 수 있다 — 화면이 [ShowSummary.status] 로 거른다.
  Future<List<ShowSummary>> search(String keyword);

  /// 인기 아티스트. 홈 격자에 들어갈 만큼만 온다. 서버에 인기 집계가 아직
  /// 없어 지금은 최근 등록순이다.
  Future<List<ArtistSummary>> fetchPopularArtists();

  /// 검색 화면의 추천 검색어로 내세울 아티스트. 원형 아바타 한 줄이다.
  Future<List<ArtistSummary>> fetchRecommendedArtists();

  /// 실시간 인기 검색어. 순위순이고 기준 시각이 함께 온다.
  Future<TrendingKeywords> fetchTrendingKeywords();

  /// 이름에 [keyword] 가 들어 있는 아티스트. 검색 결과의 "관련 아티스트" 다.
  /// 이름순이고 한 줄에 보일 만큼만 온다.
  Future<List<ArtistSummary>> searchArtists(String keyword);
}
