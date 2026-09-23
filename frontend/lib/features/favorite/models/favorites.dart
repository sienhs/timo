import 'package:flutter/foundation.dart';

import 'favorite_artist.dart';
import 'favorite_show.dart';

/// 찜한 공연·아티스트 목록. 최근에 찜한 것이 앞이다. 같은 공연은 하나만·다시
/// 누르면 빠진다는 규칙을 여기 한 곳에 두고, 불변 객체라 바꿀 때마다 새 객체를
/// 돌려준다. 공연은 서버, 아티스트는 기기에 남기며 그 갈래는 `FavoriteStore` 몫이다.
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

  /// 찜한 아티스트의 스냅샷을 [latest] 의 것으로 바꾼다. 순서는 그대로고 [latest]
  /// 에 없는 아티스트는 건드리지 않는다. 기기에 남긴 옛 모습을 서버가 준 최신
  /// 모습으로 맞출 때 쓴다.
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
