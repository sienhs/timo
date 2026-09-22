import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/favorite/data/favorite_artist_store.dart';
import 'package:timo/features/favorite/data/favorite_store.dart';
import 'package:timo/features/favorite/data/mock_favorite_api.dart';
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

    test('서버에서 받은 목록으로 공연만 갈아 끼운다', () {
      const favorites = Favorites(
        shows: [bigbang],
        artists: [FavoriteArtist(name: '아이유')],
      );

      final replaced = favorites.withShows([rescene]);

      expect(replaced.shows, [rescene]);
      expect(replaced.artists, favorites.artists);
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
    late MockFavoriteApi api;
    late InMemoryFavoriteArtistStore artistStore;
    late FavoriteStore store;

    /// [shows] 는 서버가 들고 있는 찜 공연, [artists] 는 기기에 남아 있던 것.
    void givenStore({
      List<FavoriteShow> shows = const [],
      List<FavoriteArtist> artists = const [],
    }) {
      api = MockFavoriteApi(shows: shows);
      artistStore = InMemoryFavoriteArtistStore(artists);
      // 디바운스는 0 으로 둔다. 연타를 한 번으로 묶는지 보는 테스트만 실제
      // 간격을 쓴다.
      store = FavoriteStore(
        api: api,
        artistStore: artistStore,
        toggleDebounce: Duration.zero,
      );
      addTearDown(store.dispose);
    }

    test('바꾸면 알리고, 같은 목록이면 알리지 않는다', () async {
      givenStore();
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
    });

    test('공연을 찜하면 서버에도 남고, 다시 누르면 서버에서도 빠진다', () async {
      givenStore();

      await store.toggleShow(bigbang);
      expect(api.wishedIds, [bigbang.id]);

      await store.toggleShow(bigbang);
      expect(api.wishedIds, isEmpty);
      expect(store.favorites.shows, isEmpty);
    });

    test('하트는 서버 응답을 기다리지 않고 먼저 채워진다', () async {
      givenStore();
      api.failing = false;

      final pending = store.toggleShow(iu);

      // 응답 전에 이미 목록에 있다. 검색 결과의 하트가 바로 채워지는 이유다.
      expect(store.favorites.hasShow(iu.id), isTrue);
      await pending;
    });

    test('서버가 거절하면 하트를 되돌리고 그대로 알린다', () async {
      givenStore();
      api.failing = true;

      await expectLater(
        store.toggleShow(bigbang),
        throwsA(isA<ApiException>()),
      );

      // 서버에 없는 찜이 채워진 채로 남으면 다음에 앱을 켤 때 조용히 사라진다.
      expect(store.favorites.hasShow(bigbang.id), isFalse);
    });

    test('빼기가 실패하면 공연이 목록으로 되돌아온다', () async {
      givenStore(shows: [bigbang]);
      await store.loadShows();
      api.failing = true;

      await expectLater(store.removeShow(bigbang.id), throwsA(anything));

      expect(store.favorites.hasShow(bigbang.id), isTrue);
    });

    test('서버 목록을 받아 공연만 바꾼다', () async {
      givenStore(shows: [bigbang, iu], artists: const [
        FavoriteArtist(name: '아이유'),
      ]);
      await store.restoreArtists();

      final shows = await store.loadShows();

      expect(shows.map((show) => show.id), [bigbang.id, iu.id]);
      expect(store.favorites.shows.map((show) => show.id), [
        bigbang.id,
        iu.id,
      ]);
      // 아티스트는 기기 것이라 그대로다.
      expect(store.favorites.artists.single.name, '아이유');
    });

    test('로그아웃하면 공연만 버리고 아티스트는 남긴다', () async {
      givenStore(shows: [bigbang], artists: const [
        FavoriteArtist(name: '아이유'),
      ]);
      await store.restoreArtists();
      await store.loadShows();

      store.clearShows();

      expect(store.favorites.shows, isEmpty);
      expect(store.favorites.artists, hasLength(1));
    });

    test('연타해도 요청은 한 번만 나간다', () async {
      givenStore();

      // 켜고 끄고 켰다. 손이 멈춘 뒤의 의도는 '켬' 하나다.
      store.toggleShow(bigbang);
      store.toggleShow(bigbang);
      await store.toggleShow(bigbang);

      expect(api.sendCount, 1);
      expect(api.wishedIds, [bigbang.id]);
      expect(store.favorites.hasShow(bigbang.id), isTrue);
    });

    test('연타가 제자리로 돌아오면 아무것도 보내지 않는다', () async {
      givenStore();

      store.toggleShow(bigbang);
      await store.toggleShow(bigbang);

      // 서버는 처음부터 이 상태였다. 보낼 것이 없다.
      expect(api.sendCount, 0);
      expect(store.favorites.hasShow(bigbang.id), isFalse);
    });

    test('연타 중에는 화면이 매번 바뀐다', () async {
      givenStore();
      var notified = 0;
      store.addListener(() => notified++);

      store.toggleShow(bigbang);
      expect(store.favorites.hasShow(bigbang.id), isTrue);
      await store.toggleShow(bigbang);

      // 요청은 묶여도 하트는 누르는 족족 따라와야 한다.
      expect(notified, 2);
    });

    test('손이 멈출 때까지 기다렸다 보낸다', () async {
      api = MockFavoriteApi();
      artistStore = InMemoryFavoriteArtistStore();
      store = FavoriteStore(
        api: api,
        artistStore: artistStore,
        toggleDebounce: const Duration(milliseconds: 40),
      );
      addTearDown(store.dispose);

      final sent = store.toggleShow(bigbang);

      // 아직 기다리는 중이다. 화면만 바뀌어 있다.
      expect(api.sendCount, 0);
      expect(store.favorites.hasShow(bigbang.id), isTrue);

      await sent;
      expect(api.sendCount, 1);
    });

    test('로그아웃하면 보내기를 기다리던 하트도 버린다', () async {
      givenStore();

      final sent = store.toggleShow(bigbang);
      store.clearShows();
      await sent;

      // 앞사람의 찜이 로그아웃 뒤에 나가면 안 된다.
      expect(api.sendCount, 0);
    });

    test('아티스트 찜은 기기에만 남는다', () async {
      givenStore();

      await store.toggleArtist(const FavoriteArtist(name: '아이유'));

      expect(await artistStore.load(), [const FavoriteArtist(name: '아이유')]);
      // 아티스트는 서버에 보내지 않는다.
      expect(api.wishedIds, isEmpty);
    });
  });
}
