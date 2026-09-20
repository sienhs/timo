import 'package:flutter/foundation.dart';

import 'favorite_artist.dart';
import 'favorite_show.dart';

/// 찜한 공연·아티스트 목록. 최근에 찜한 것이 앞이다.
///
/// 규칙(같은 공연은 하나만 · 다시 누르면 빠진다)을 여기 한 곳에 둔다. 저장소는
/// 이 객체를 통째로 넣고 빼는 것만 알고, 화면은 이 객체의 메서드만 부른다.
/// 불변 객체라 바꿀 때마다 새 객체를 돌려준다 — 최근 검색어(`RecentSearches`)
/// 와 같은 짜임이다.
///
/// 공연과 아티스트가 한 객체에 있지만 남는 곳은 다르다. 공연은 서버(찜 API),
/// 아티스트는 기기다. 화면은 둘을 한 화면(탭)에서 함께 그리므로 목록 자체는
/// 하나로 두고, 어디에 남길지는 [FavoriteStore] 가 가른다.
@immutable
class Favorites {
  const Favorites({this.shows = const [], this.artists = const []});

  final List<FavoriteShow> shows;
  final List<FavoriteArtist> artists;

  bool hasShow(int id) => shows.any((show) => show.id == id);

  bool hasArtist(String name) => artists.any((artist) => artist.name == name);

  /// 없으면 맨 앞에 넣고, 있으면 뺀다. 하트를 한 번 누르는 동작 그대로다.
  Favorites toggleShow(FavoriteShow show) =>
      hasShow(show.id) ? removeShow(show.id) : withShows([show, ...shows]);

  Favorites toggleArtist(FavoriteArtist artist) => hasArtist(artist.name)
      ? removeArtist(artist.name)
      : withArtists([artist, ...artists]);

  Favorites removeShow(int id) =>
      withShows(shows.where((show) => show.id != id));

  Favorites removeArtist(String name) =>
      withArtists(artists.where((artist) => artist.name != name));

  /// 찜한 아티스트의 스냅샷을 [latest] 의 것으로 바꾼다. 순서는 그대로다.
  ///
  /// 아티스트 찜은 그 순간의 모습을 기기에 남기는 것이라, 서버가 나중에 사진을
  /// 붙이거나 바꿔도 목록은 옛 모습에 머문다. 검색 결과처럼 서버가 준 최신
  /// 모습을 다시 만났을 때 여기로 맞춘다. [latest] 에 없는 아티스트는 건드리지
  /// 않는다.
  Favorites refreshArtists(Iterable<FavoriteArtist> latest) {
    final byName = {for (final artist in latest) artist.name: artist};
    return withArtists(artists.map((artist) => byName[artist.name] ?? artist));
  }

  /// 공연만 갈아 끼운다. 서버에서 받아 온 목록으로 통째로 바꿀 때 쓴다.
  Favorites withShows(Iterable<FavoriteShow> next) =>
      Favorites(shows: List.unmodifiable(next), artists: artists);

  /// 아티스트만 갈아 끼운다. 기기에서 되살린 목록을 넣을 때 쓴다.
  Favorites withArtists(Iterable<FavoriteArtist> next) =>
      Favorites(shows: shows, artists: List.unmodifiable(next));

  @override
  bool operator ==(Object other) =>
      other is Favorites &&
      listEquals(other.shows, shows) &&
      listEquals(other.artists, artists);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(shows), Object.hashAll(artists));
}
