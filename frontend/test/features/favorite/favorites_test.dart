import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/models/favorite_artist.dart';
import 'package:timo/features/favorite/models/favorite_filters.dart';
import 'package:timo/features/favorite/models/favorite_show.dart';
import 'package:timo/features/favorite/models/favorites.dart';

/// 찜 목록 규칙. 화면·저장소와 떼어 놓고 목록만 본다.
void main() {
  const bigbang = FavoriteShow(
    id: 1,
    title: '2026 BIGBANG',
    venueName: '올림픽공원 체조경기장',
    isOnSale: true,
  );
  final iu = FavoriteShow(
    id: 2,
    title: '2026 아이유 콘서트',
    venueName: '고척스카이돔',
    isOnSale: true,
    startAt: DateTime(2026, 11, 4, 18),
    posterImageUrl: 'poster/iu.jpg',
  );
  final rescene = FavoriteShow(
    id: 3,
    title: '2026 RE:MIND: 리센느',
    venueName: '올림픽공원 체조경기장',
    isOnSale: false,
    startAt: DateTime(2026, 5, 20, 19),
  );

  group('Favorites', () {
    test('새로 찜한 공연은 맨 앞에 들어간다', () {
      final favorites = const Favorites(shows: [bigbang]).toggleShow(iu);

      expect(favorites.shows, [iu, bigbang]);
      expect(favorites.hasShow(iu.id), isTrue);
    });

    test('이미 찜한 공연을 다시 누르면 빠진다', () {
      final favorites = Favorites(shows: [iu, bigbang]).toggleShow(bigbang);

      expect(favorites.shows, [iu]);
      expect(favorites.hasShow(bigbang.id), isFalse);
    });

    test('같은 번호면 같은 공연이다 — 제목이 달라도 하나만 남는다', () {
      const renamed = FavoriteShow(
        id: 1,
        title: 'BIGBANG WORLD TOUR',
        venueName: '올림픽공원 체조경기장',
        isOnSale: true,
      );
      final favorites = const Favorites(shows: [bigbang]).toggleShow(renamed);

      expect(favorites.shows, isEmpty);
    });

    test('아티스트는 이름으로 가른다', () {
      const iuArtist = FavoriteArtist(name: '아이유');
      var favorites = const Favorites().toggleArtist(iuArtist);
      expect(favorites.hasArtist('아이유'), isTrue);

      favorites = favorites.toggleArtist(
        const FavoriteArtist(name: '아이유', profileImageUrl: 'iu.jpg'),
      );
      expect(favorites.artists, isEmpty);
    });

    test('찜한 아티스트의 스냅샷만 최신으로 바뀌고 순서는 그대로다', () {
      const iuArtist = FavoriteArtist(name: '아이유');
      const vArtist = FavoriteArtist(name: '뷔');
      const iuWithPhoto = FavoriteArtist(
        name: '아이유',
        profileImageUrl: 'artist/iu.jpg',
      );
      const stranger = FavoriteArtist(name: '리센느', profileImageUrl: 'a.jpg');

      final favorites = const Favorites(
        artists: [vArtist, iuArtist],
      ).refreshArtists([iuWithPhoto, stranger]);

      expect(favorites.artists, [vArtist, iuWithPhoto]);
    });

    test('공연을 빼도 아티스트는 그대로다', () {
      final favorites = Favorites(
        shows: [iu],
        artists: const [FavoriteArtist(name: '아이유')],
      ).removeShow(iu.id);

      expect(favorites.shows, isEmpty);
      expect(favorites.artists, hasLength(1));
    });

    test('JSON 으로 내보내고 되살리면 같다', () {
      final favorites = Favorites(
        shows: [iu, rescene, bigbang],
        artists: const [
          FavoriteArtist(name: '아이유', profileImageUrl: 'iu.jpg'),
          FavoriteArtist(name: 'BIGBANG'),
        ],
      );

      expect(Favorites.fromJson(favorites.toJson()), favorites);
    });

    test('알 수 없는 항목이 섞인 JSON 은 그 항목만 건너뛴다', () {
      final favorites = Favorites.fromJson({
        'shows': [bigbang.toJson(), 'garbage', null],
        'artists': 'not a list',
      });

      expect(favorites.shows, [bigbang]);
      expect(favorites.artists, isEmpty);
    });
  });

  group('FavoriteShow', () {
    test('일시는 앱 공통 표기로 찍고, 미정이면 문구로 대신한다', () {
      expect(iu.dateLabel, '2026.11.04 18:00');
      expect(bigbang.dateLabel, '일정 미정');
    });
  });

  group('필터·정렬', () {
    final shows = [bigbang, iu, rescene];

    test('판매 상태 필터', () {
      expect(shows.where(FavoriteShowFilter.all.accepts), shows);
      expect(shows.where(FavoriteShowFilter.onSale.accepts), [bigbang, iu]);
      expect(shows.where(FavoriteShowFilter.closed.accepts), [rescene]);
    });

    test('최근 찜한 순은 저장 순서 그대로다', () {
      expect(FavoriteShowSort.recent.apply(shows), shows);
    });

    test('공연 임박 순은 시작이 빠른 것부터, 일정 미정은 맨 뒤다', () {
      expect(FavoriteShowSort.upcoming.apply(shows), [rescene, iu, bigbang]);
      // 원본은 건드리지 않는다.
      expect(shows, [bigbang, iu, rescene]);
    });

    test('아티스트 이름 순', () {
      const artists = [
        FavoriteArtist(name: '리센느'),
        FavoriteArtist(name: 'BIGBANG'),
        FavoriteArtist(name: '아이유'),
      ];
      expect(FavoriteArtistSort.name.apply(artists).map((a) => a.name), [
        'BIGBANG',
        '리센느',
        '아이유',
      ]);
    });

    test('검색어는 대소문자를 가리지 않고, 공백만이면 전부 통과다', () {
      expect(matchesKeyword('2026 BIGBANG', 'bigbang'), isTrue);
      expect(matchesKeyword('2026 아이유 콘서트', ' 아이유 '), isTrue);
      expect(matchesKeyword('2026 아이유 콘서트', '빅뱅'), isFalse);
      expect(matchesKeyword('아무거나', '   '), isTrue);
    });
  });

  group('FavoriteStore', () {
    test('바꾸면 알리고, 같은 목록이면 알리지 않는다', () async {
      final store = InMemoryFavoriteStore();
      var notified = 0;
      store.addListener(() => notified++);

      await store.toggleShow(bigbang);
      expect(store.favorites.shows, [bigbang]);
      expect(notified, 1);

      await store.removeShow(999);
      expect(notified, 1);

      // 찜하지 않은 아티스트의 최신 모습은 목록을 바꾸지 않는다.
      await store.refreshArtists(const [FavoriteArtist(name: '아이유')]);
      expect(notified, 1);

      store.dispose();
    });
  });
}
