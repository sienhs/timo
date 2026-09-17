import 'package:flutter/foundation.dart';

import 'favorite_artist.dart';
import 'favorite_show.dart';

/// 찜한 공연·아티스트 목록. 최근에 찜한 것이 앞이다.
///
/// 규칙(같은 공연은 하나만 · 다시 누르면 빠진다)을 여기 한 곳에 둔다. 저장소는
/// 이 객체를 통째로 넣고 빼는 것만 알고, 화면은 이 객체의 메서드만 부른다.
/// 불변 객체라 바꿀 때마다 새 객체를 돌려준다 — 최근 검색어(`RecentSearches`)
/// 와 같은 짜임이다.
@immutable
class Favorites {
  const Favorites({this.shows = const [], this.artists = const []});

  /// 기기에 남긴 JSON 을 읽는다.
  ///
  /// 모양이 어긋난 항목은 건너뛴다. 기기 파일이라 앱을 올리며 모양이 바뀌었을
  /// 수 있는데, 항목 하나 때문에 목록 전체를 잃는 것보다 그 항목만 버리는 쪽이
  /// 낫다.
  factory Favorites.fromJson(Map<String, dynamic> json) => Favorites(
    shows: List.unmodifiable(
      _entries(json['shows']).map(FavoriteShow.fromJson),
    ),
    artists: List.unmodifiable(
      _entries(json['artists']).map(FavoriteArtist.fromJson),
    ),
  );

  /// 목록이면 그 안의 객체만, 목록이 아니면 빈 목록.
  static Iterable<Map<String, dynamic>> _entries(Object? raw) => switch (raw) {
    final List list => list.whereType<Map<String, dynamic>>(),
    _ => const [],
  };

  final List<FavoriteShow> shows;
  final List<FavoriteArtist> artists;

  bool hasShow(int id) => shows.any((show) => show.id == id);

  bool hasArtist(String name) => artists.any((artist) => artist.name == name);

  /// 없으면 맨 앞에 넣고, 있으면 뺀다. 하트를 한 번 누르는 동작 그대로다.
  Favorites toggleShow(FavoriteShow show) =>
      hasShow(show.id) ? removeShow(show.id) : _withShows([show, ...shows]);

  Favorites toggleArtist(FavoriteArtist artist) => hasArtist(artist.name)
      ? removeArtist(artist.name)
      : _withArtists([artist, ...artists]);

  Favorites removeShow(int id) =>
      _withShows(shows.where((show) => show.id != id));

  Favorites removeArtist(String name) =>
      _withArtists(artists.where((artist) => artist.name != name));

  Favorites _withShows(Iterable<FavoriteShow> next) =>
      Favorites(shows: List.unmodifiable(next), artists: artists);

  Favorites _withArtists(Iterable<FavoriteArtist> next) =>
      Favorites(shows: shows, artists: List.unmodifiable(next));

  Map<String, dynamic> toJson() => {
    'shows': [for (final show in shows) show.toJson()],
    'artists': [for (final artist in artists) artist.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is Favorites &&
      listEquals(other.shows, shows) &&
      listEquals(other.artists, artists);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(shows), Object.hashAll(artists));
}
