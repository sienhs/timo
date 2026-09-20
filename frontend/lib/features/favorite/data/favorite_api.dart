import '../models/favorite_show.dart';

/// 공연 찜을 서버에 남기고 읽는 일.
///
/// 아티스트 찜은 여기 없다. 서버에 아티스트 찜이 없어(아티스트에 아직 id 도
/// 없다) 기기에만 남긴다 — 그쪽은 [FavoriteArtistStore] 가 맡는다.
///
/// 화면은 이 약속만 알고, 실제로 서버에 가는지(`HttpFavoriteApi`) 메모리에서
/// 흉내 내는지(`MockFavoriteApi`) 는 앱이 정한다. 홈의 `HomeApi`, 상세의
/// `ShowApi` 와 같은 구조다.
///
/// 반환 규칙: 성공하면 값을, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 모든 주소가 로그인을 요구하므로 로그아웃 상태로 부르면 401 이다 —
/// 부르기 전에 로그인 여부를 보는 것은 화면 몫이다.
abstract class FavoriteApi {
  /// 내가 찜한 공연. 최근 찜한 순이다.
  Future<List<FavoriteShow>> fetchShows();

  /// 찜한다. 이미 찜했어도 성공이다(서버가 멱등).
  Future<void> addShow(int concertId);

  /// 찜을 푼다. 찜하지 않았어도 성공이다(서버가 멱등).
  Future<void> removeShow(int concertId);
}
