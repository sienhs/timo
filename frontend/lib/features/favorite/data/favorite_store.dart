import 'package:flutter/foundation.dart';

import '../models/favorite_artist.dart';
import '../models/favorite_show.dart';
import '../models/favorites.dart';
import 'favorite_api.dart';
import 'favorite_artist_store.dart';

/// 앱이 들고 있는 찜 목록.
///
/// 공연과 아티스트가 남는 곳이 다르다. **공연은 서버**([FavoriteApi]) 라
/// 기기를 바꿔도 따라오고, **아티스트는 기기**([FavoriteArtistStore]) 라 이
/// 기기에만 있다. 화면은 그 차이를 모른 채 [favorites] 하나만 본다.
///
/// [ChangeNotifier] 인 이유는 하트가 여러 화면에 있기 때문이다. 검색 결과에서
/// 찜한 공연이 상세 화면의 하트에도, 찜리스트에도 바로 보여야 한다. 그 알림을
/// `FavoriteScope` 가 화면으로 나른다.
///
/// 공연 쪽은 **낙관적**이다. 하트를 누르면 화면을 먼저 바꾸고 서버에 보낸다.
/// 실패하면 되돌리고 예외를 그대로 던진다 — 화면이 그 사실을 알려야 한다.
/// 눌린 채로 두면 서버에는 없는 찜이 다음에 앱을 켤 때 조용히 사라진다.
/// 아티스트 쪽은 예전처럼 저장 실패를 삼킨다. 기기 저장소 오류는 사용자가
/// 할 수 있는 일이 없고, 이번 실행 동안의 화면은 이미 맞다.
class FavoriteStore extends ChangeNotifier {
  FavoriteStore({required this._api, required this._artistStore});

  final FavoriteApi _api;
  final FavoriteArtistStore _artistStore;

  Favorites _favorites = const Favorites();

  /// 지금 찜 목록. 최근에 찜한 것이 앞이다.
  Favorites get favorites => _favorites;

  /// 서버에서 찜 공연을 받아 목록을 통째로 바꾼다. 로그인 상태에서만 부른다.
  ///
  /// 실패는 그대로 던진다. 찜리스트 화면은 `AsyncBoundary` 로 받아 '다시 시도'
  /// 를 보여주고, 앱이 켜질 때 부르는 쪽은 삼킨다(하트가 빈 채로 시작할 뿐이다).
  Future<List<FavoriteShow>> loadShows() async {
    final shows = await _api.fetchShows();
    _apply(_favorites.withShows(shows));
    return shows;
  }

  /// 들고 있던 찜 공연을 버린다. 로그아웃할 때다 — 다음 사람의 하트가 앞사람의
  /// 찜으로 채워져 보이면 안 된다.
  void clearShows() {
    if (_favorites.shows.isEmpty) return;
    _apply(_favorites.withShows(const []));
  }

  /// 기기에 남아 있던 아티스트 찜을 되살린다. 앱이 켜질 때 한 번 부른다.
  Future<void> restoreArtists() async {
    final artists = await _artistStore.load();
    if (artists.isEmpty) return;
    _apply(_favorites.withArtists(artists));
  }

  /// 찜하거나 뺀다. 화면을 먼저 바꾸고 서버에 보낸다.
  ///
  /// 실패하면 이 공연만 되돌린다. 되돌리는 사이 다른 하트를 눌렀을 수도 있어
  /// 목록 전체를 이전 것으로 덮지는 않는다. 빼기가 실패해 되살릴 때는 맨 앞에
  /// 들어간다 — 원래 자리는 잃지만, 다음 [loadShows] 가 서버 순서로 맞춘다.
  Future<void> toggleShow(FavoriteShow show) async {
    final wasWished = _favorites.hasShow(show.id);
    _apply(_favorites.toggleShow(show));
    try {
      if (wasWished) {
        await _api.removeShow(show.id);
      } else {
        await _api.addShow(show.id);
      }
    } catch (_) {
      if (_favorites.hasShow(show.id) != wasWished) {
        _apply(_favorites.toggleShow(show));
      }
      rethrow;
    }
  }

  /// 찜리스트에서 뺀다. 목록에 없으면 아무 일도 하지 않는다.
  Future<void> removeShow(int id) async {
    for (final show in _favorites.shows) {
      if (show.id == id) return toggleShow(show);
    }
  }

  Future<void> toggleArtist(FavoriteArtist artist) =>
      _updateArtists(_favorites.toggleArtist(artist));

  Future<void> removeArtist(String name) =>
      _updateArtists(_favorites.removeArtist(name));

  /// 이미 찜한 아티스트의 사진 등을 서버가 준 최신 모습으로 맞춘다. 규칙은
  /// [Favorites.refreshArtists] 가 정한다. 바뀐 게 없으면 알리지도 저장하지도
  /// 않는다.
  Future<void> refreshArtists(Iterable<FavoriteArtist> latest) =>
      _updateArtists(_favorites.refreshArtists(latest));

  /// 아티스트 목록을 바꾸고 기기에 남긴다. 저장 실패는 삼킨다(클래스 주석).
  Future<void> _updateArtists(Favorites next) async {
    if (next == _favorites) return;
    _apply(next);
    try {
      await _artistStore.save(next.artists);
    } catch (_) {
      // 기기 설정 저장소 오류. 다음에 하트를 누를 때 다시 저장된다.
    }
  }

  void _apply(Favorites next) {
    if (next == _favorites) return;
    _favorites = next;
    notifyListeners();
  }
}
