import '../models/artist_summary.dart';
import '../models/show_summary.dart';

/// 홈 화면이 서버에 요청하는 일 네 가지.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 [HttpHomeApi] 가 실제 서버에 요청하고,
/// 테스트는 [MockHomeApi] 를 쓴다. 인증의 `AuthApi` 와 같은 구조다.
///
/// 공연 셋은 서버의 공연 목록 API 하나를 조건만 달리 부른다. 홈 전용
/// 엔드포인트는 없다. 그래도 메서드를 나눈 이유는, 화면이 "오픈 임박을 달라"
/// 고만 하고 그게 어떤 정렬·필터인지는 몰라야 서버 규약이 바뀌어도 화면이
/// 그대로기 때문이다. 아티스트는 서버 API 가 아직 없어 구현이 목업을 돌려준다
/// — 화면은 그 사정을 모른다.
///
/// 반환 규칙: 성공하면 목록을, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 빈 목록은 실패가 아니라 "해당하는 공연이 없다" 는 정상 결과다.
abstract class HomeApi {
  /// 예매 오픈이 가까운 순. 아직 오픈하지 않은 공연만 온다.
  Future<List<ShowSummary>> fetchTicketOpenSoon();

  /// 많이 본 순. 목록 순서가 곧 순위다.
  Future<List<ShowSummary>> fetchPopular();

  /// 공연명에 [keyword] 가 들어 있는 공연. 최근 등록순.
  Future<List<ShowSummary>> search(String keyword);

  /// 인기 아티스트. 홈 격자에 들어갈 만큼만 온다.
  Future<List<ArtistSummary>> fetchPopularArtists();
}
