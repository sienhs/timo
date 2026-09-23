import '../models/favorite_show.dart';

/// 공연 찜을 서버에 남기고 읽는 일. 구현은 `HttpFavoriteApi`·`MockFavoriteApi`,
/// 실패는 `ApiException` 으로 던진다. 모든 주소가 로그인을 요구해 로그아웃
/// 상태로 부르면 401 이다 — 로그인 여부는 부르기 전에 화면이 본다.
/// 아티스트 찜은 서버에 없어 `FavoriteArtistStore` 가 기기에만 남긴다.
abstract class FavoriteApi {
  /// 내가 찜한 공연. 최근 찜한 순이다.
  Future<List<FavoriteShow>> fetchShows();

  /// 찜한다. 이미 찜했어도 성공이다(서버가 멱등).
  Future<void> addShow(int concertId);

  /// 찜을 푼다. 찜하지 않았어도 성공이다(서버가 멱등).
  Future<void> removeShow(int concertId);
}
