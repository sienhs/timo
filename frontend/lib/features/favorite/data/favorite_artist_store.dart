import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/favorite_artist.dart';

/// 찜한 아티스트를 기기에 넣고 빼는 곳. 서버에 아티스트 찜 API 가 없어(id 도
/// 없다) 최근 검색어처럼 기기에만 남기고, 로그아웃해도 비우지 않는다 — 계정이
/// 아니라 이 기기의 기록이다. 위젯 테스트는 [InMemoryFavoriteArtistStore] 를 쓴다.
abstract class FavoriteArtistStore {
  /// 기기에 남아 있던 목록. 없으면 빈 목록이다.
  Future<List<FavoriteArtist>> load();

  /// 바뀐 목록을 기기에 남긴다.
  Future<void> save(List<FavoriteArtist> artists);
}

/// 기기 설정 저장소(shared_preferences)에 JSON 한 줄로 넣는 진짜 구현.
class SharedPreferencesFavoriteArtistStore implements FavoriteArtistStore {
  /// 저장된 JSON 에 `shows` 가 함께 있어도 읽지 않는다 — 공연 찜은 서버가 들고
  /// 있고, 기기에 남은 것은 다른 계정의 것일 수 있어 올려 보내지 않는다.
  static const key = 'favorite.list';

  static const _artistsField = 'artists';

  @override
  Future<List<FavoriteArtist>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    return _artistsOf(decoded[_artistsField]);
  }

  @override
  Future<void> save(List<FavoriteArtist> artists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        _artistsField: [for (final artist in artists) artist.toJson()],
      }),
    );
  }

  /// 모양이 어긋난 항목은 건너뛴다. 기기 파일이라 앱을 올리며 모양이 바뀌었을
  /// 수 있는데, 항목 하나 때문에 목록 전체를 잃는 것보다 그 항목만 버리는 쪽이
  /// 낫다.
  static List<FavoriteArtist> _artistsOf(Object? raw) => switch (raw) {
    final List list => [
      for (final entry in list.whereType<Map<String, dynamic>>())
        FavoriteArtist.fromJson(entry),
    ],
    _ => const [],
  };
}

/// 메모리에만 두는 구현. 테스트와, 플러그인이 없는 자리(위젯 테스트의 App)에서
/// 쓴다. 앱을 끄면 사라진다.
class InMemoryFavoriteArtistStore implements FavoriteArtistStore {
  InMemoryFavoriteArtistStore([List<FavoriteArtist> initial = const []])
    : _artists = [...initial];

  List<FavoriteArtist> _artists;

  @override
  Future<List<FavoriteArtist>> load() async => List.unmodifiable(_artists);

  @override
  Future<void> save(List<FavoriteArtist> artists) async {
    _artists = [...artists];
  }
}
