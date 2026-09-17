import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_artist.dart';
import '../models/favorite_show.dart';
import '../models/favorites.dart';

/// 찜 목록을 기기에 넣고 빼는 곳.
///
/// 찜 API 가 아직 없어(백엔드 후순위) 최근 검색어와 같이 **기기에만** 남긴다.
/// 앱에서는 [SharedPreferencesFavoriteStore] 가 기기 설정 저장소에, 테스트는
/// [InMemoryFavoriteStore] 를 꽂는다 — 위젯 테스트는 플러그인을 못 쓴다.
///
/// [ChangeNotifier] 인 이유는 하트가 여러 화면에 있기 때문이다. 검색 결과에서
/// 찜한 공연이 상세 화면의 하트에도, 찜리스트에도 바로 보여야 한다. 그 알림을
/// `FavoriteScope` 가 화면으로 나른다. 소장품 저장소(`TicketStore`)와 같은
/// 짜임이다.
///
/// 규칙(하나만 · 다시 누르면 빠짐)은 [Favorites] 가 정한다. 저장소는 바뀐
/// 목록을 그대로 남길 뿐이다.
abstract class FavoriteStore extends ChangeNotifier {
  Favorites _favorites = const Favorites();

  /// 지금 찜 목록. 최근에 찜한 것이 앞이다.
  Favorites get favorites => _favorites;

  Future<void> toggleShow(FavoriteShow show) =>
      _update(_favorites.toggleShow(show));

  Future<void> toggleArtist(FavoriteArtist artist) =>
      _update(_favorites.toggleArtist(artist));

  Future<void> removeShow(int id) => _update(_favorites.removeShow(id));

  Future<void> removeArtist(String name) =>
      _update(_favorites.removeArtist(name));

  /// 화면을 먼저 바꾸고 저장은 뒤따른다. 저장이 실패해도 이번 실행 동안의
  /// 화면은 이미 맞고, 다음에 하트를 누를 때 다시 저장되므로 알리지 않는다
  /// — 최근 검색어가 저장 실패를 삼키는 것과 같은 판단이다.
  Future<void> _update(Favorites next) async {
    if (next == _favorites) return;
    _favorites = next;
    notifyListeners();
    try {
      await persist(next);
    } catch (_) {
      // 기기 설정 저장소 오류. 위 주석대로 조용히 넘어간다.
    }
  }

  /// 되살린 목록으로 바꾼다. 구현이 기기에서 읽어 온 뒤 부른다.
  @protected
  void replace(Favorites favorites) {
    _favorites = favorites;
    notifyListeners();
  }

  /// 바뀐 목록을 기기에 남긴다.
  @protected
  Future<void> persist(Favorites favorites);
}

/// 기기 설정 저장소(shared_preferences)에 JSON 한 줄로 넣는 진짜 구현.
///
/// 앱을 켤 때 [restore] 로 되살려야 한다. 검색 결과의 하트가 첫 화면부터 찜
/// 여부를 맞게 그리려면 그 전에 읽혀 있어야 해서, main 이 띄우기 전에 기다린다.
class SharedPreferencesFavoriteStore extends FavoriteStore {
  SharedPreferencesFavoriteStore();

  static const key = 'favorite.list';

  /// 저장된 목록을 읽어 온다. 없으면 빈 목록이다.
  ///
  /// 읽지 못하면(저장소 오류·깨진 JSON) 예외를 그대로 던진다. 빈 목록으로
  /// 시작하고 다음 저장에서 덮어쓸지는 호출부(main)가 정한다.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return;
    replace(Favorites.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }

  @override
  Future<void> persist(Favorites favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(favorites.toJson()));
  }
}

/// 메모리에만 두는 구현. 테스트와, 플러그인이 없는 자리(위젯 테스트의 App)에서
/// 쓴다. 앱을 끄면 사라진다.
class InMemoryFavoriteStore extends FavoriteStore {
  InMemoryFavoriteStore([Favorites initial = const Favorites()]) {
    replace(initial);
  }

  @override
  Future<void> persist(Favorites favorites) async {}
}
