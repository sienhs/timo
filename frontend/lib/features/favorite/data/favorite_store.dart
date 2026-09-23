import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/favorite_artist.dart';
import '../models/favorite_show.dart';
import '../models/favorites.dart';
import 'favorite_api.dart';
import 'favorite_artist_store.dart';

/// 서버로 보내기를 기다리는 하트 한 건. 같은 공연을 연타하는 동안 이 객체
/// 하나가 살아 있고 타이머만 새로 걸린다. 그래서 몇 번을 누르든 요청은 한 번이다.
class _PendingToggle {
  _PendingToggle({required this.show, required this.serverState});

  /// 되돌릴 때 쓸 공연. 누를 때마다 최신 것으로 바꾼다 — 목록이 다시 도착해
  /// 카드 내용이 바뀌었을 수 있다.
  FavoriteShow show;

  /// 연타가 시작되기 **전**의 상태, 즉 서버가 아는 값. 보낼 때 지금 상태와
  /// 같으면 보내지 않는다(켰다 껐으면 서버는 그대로다).
  final bool serverState;

  /// 이 연타를 기다리는 호출부들. 하나의 전송 결과를 함께 받는다.
  final Completer<void> done = Completer<void>();

  Timer? timer;
}

/// 앱이 들고 있는 찜 목록. 공연은 서버([FavoriteApi]), 아티스트는 기기
/// ([FavoriteArtistStore])에 남고 화면은 [favorites] 하나만 본다. 공연 쪽은
/// 낙관적이다 — 화면을 먼저 바꾸고 [FavoriteLimits.toggleDebounce] 뒤에 보내며,
/// 실패하면 되돌리고 예외를 던진다. 아티스트 쪽은 저장 실패를 삼킨다.
class FavoriteStore extends ChangeNotifier {
  FavoriteStore({
    required this._api,
    required this._artistStore,
    this._toggleDebounce = FavoriteLimits.toggleDebounce,
  });

  final FavoriteApi _api;
  final FavoriteArtistStore _artistStore;

  /// 하트를 누르고 서버로 보내기까지 기다리는 시간. 테스트는 0 을 넣는다.
  final Duration _toggleDebounce;

  /// 보내기를 기다리는 하트. 공연 번호로 찾는다.
  final Map<int, _PendingToggle> _pending = {};

  Favorites _favorites = const Favorites();

  /// 지금 찜 목록. 최근에 찜한 것이 앞이다.
  Favorites get favorites => _favorites;

  /// 서버에서 찜 공연을 받아 목록을 통째로 바꾼다. 로그인 상태에서만 부른다.
  /// 실패는 그대로 던진다 — 찜리스트 화면은 '다시 시도' 를 보여주고, 앱이 켜질
  /// 때 부르는 쪽은 삼킨다.
  Future<List<FavoriteShow>> loadShows() async {
    final shows = await _api.fetchShows();
    _apply(_favorites.withShows(shows));
    return shows;
  }

  /// 들고 있던 찜 공연을 버린다. 로그아웃할 때다. 보내기를 기다리던 하트도
  /// 버린다 — 앞사람의 찜이 나가면 안 되고, 나가 봐야 토큰이 없어 401 이다.
  void clearShows() {
    _discardPending();
    if (_favorites.shows.isEmpty) return;
    _apply(_favorites.withShows(const []));
  }

  /// 기기에 남아 있던 아티스트 찜을 되살린다. 앱이 켜질 때 한 번 부른다.
  Future<void> restoreArtists() async {
    final artists = await _artistStore.load();
    if (artists.isEmpty) return;
    _apply(_favorites.withArtists(artists));
  }

  /// 찜하거나 뺀다. 화면을 먼저 바꾸고, 손이 멈추면 서버에 보낸다. 돌려주는
  /// Future 는 그 전송이 끝날 때 완결되며 연타한 호출은 모두 같은 것을 받는다.
  /// 실패하면 이 공연만 되돌린다(되살린 공연은 맨 앞, 다음 [loadShows] 가 맞춘다).
  Future<void> toggleShow(FavoriteShow show) {
    _apply(_favorites.toggleShow(show));
    // 방금 뒤집었으니 지금의 반대가 서버가 아는 상태다. 연타 중이면 앞서 잡아
    // 둔 값을 그대로 쓴다 — 그것이 이 연타가 시작되기 전의 상태다.
    final pending = _pending[show.id] ??= _PendingToggle(
      show: show,
      serverState: !_favorites.hasShow(show.id),
    );
    pending.show = show;
    pending.timer?.cancel();
    pending.timer = Timer(_toggleDebounce, () => _flushToggle(show.id));
    return pending.done.future;
  }

  /// 기다리던 하트를 서버로 보낸다.
  Future<void> _flushToggle(int id) async {
    final pending = _pending.remove(id);
    if (pending == null) return;

    final wished = _favorites.hasShow(id);
    if (wished == pending.serverState) {
      // 켰다 껐다 해서 제자리로 돌아왔다. 서버는 이미 그 상태다.
      pending.done.complete();
      return;
    }

    try {
      if (wished) {
        await _api.addShow(id);
      } else {
        await _api.removeShow(id);
      }
      pending.done.complete();
    } catch (e, stackTrace) {
      // 요청이 나가 있는 동안 또 눌렀으면 그 의도가 더 최신이다. 되돌리지도
      // 알리지도 않는다 — 곧 나갈 요청이 서버를 맞춘다(등록·해제는 멱등).
      if (_pending.containsKey(id)) {
        pending.done.complete();
        return;
      }
      if (_favorites.hasShow(id) != pending.serverState) {
        _apply(_favorites.toggleShow(pending.show));
      }
      pending.done.completeError(e, stackTrace);
    }
  }

  /// 기다리던 하트를 보내지 않고 버린다. 화면은 건드리지 않는다.
  void _discardPending() {
    for (final pending in _pending.values) {
      pending.timer?.cancel();
      if (!pending.done.isCompleted) pending.done.complete();
    }
    _pending.clear();
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

  /// 앱이 내려간다. 기다리던 하트는 보내고 간다 — 한 번 누르고 곧바로 앱을 닫는
  /// 경우다. 화면은 이미 없으므로 결과는 보지 않는다.
  @override
  void dispose() {
    for (final pending in _pending.values) {
      pending.timer?.cancel();
      final wished = _favorites.hasShow(pending.show.id);
      if (wished != pending.serverState) {
        (wished
                ? _api.addShow(pending.show.id)
                : _api.removeShow(pending.show.id))
            .ignore();
      }
      if (!pending.done.isCompleted) pending.done.complete();
    }
    _pending.clear();
    super.dispose();
  }
}
