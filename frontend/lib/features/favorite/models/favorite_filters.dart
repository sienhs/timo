import '../constants.dart';
import 'favorite_artist.dart';
import 'favorite_show.dart';

/// 공연 탭의 판매 상태 필터. 순서가 칩 줄의 순서다.
enum FavoriteShowFilter {
  all(FavoriteStrings.filterAll),
  onSale(FavoriteStrings.filterOnSale),
  closed(FavoriteStrings.filterClosed);

  const FavoriteShowFilter(this.label);

  final String label;

  bool accepts(FavoriteShow show) => switch (this) {
    all => true,
    onSale => show.isOnSale,
    closed => !show.isOnSale,
  };
}

/// 공연 탭의 정렬. 순서가 메뉴의 순서다.
enum FavoriteShowSort {
  recent(FavoriteStrings.sortRecent),
  upcoming(FavoriteStrings.sortUpcoming);

  const FavoriteShowSort(this.label);

  final String label;

  /// 목록은 최근 찜한 순으로 저장돼 있으므로 [recent] 는 그대로다.
  /// [upcoming] 은 시작이 빠른 것부터, 일정 미정은 맨 뒤다.
  List<FavoriteShow> apply(List<FavoriteShow> shows) => switch (this) {
    recent => shows,
    upcoming => [...shows]..sort(_byStartAt),
  };

  static int _byStartAt(FavoriteShow a, FavoriteShow b) {
    final aStart = a.startAt;
    final bStart = b.startAt;
    if (aStart == null) return bStart == null ? 0 : 1;
    if (bStart == null) return -1;
    return aStart.compareTo(bStart);
  }
}

/// 아티스트 탭의 정렬. 순서가 메뉴의 순서다.
enum FavoriteArtistSort {
  recent(FavoriteStrings.sortRecent),
  name(FavoriteStrings.sortName);

  const FavoriteArtistSort(this.label);

  final String label;

  List<FavoriteArtist> apply(List<FavoriteArtist> artists) => switch (this) {
    recent => artists,
    name => [...artists]..sort((a, b) => a.name.compareTo(b.name)),
  };
}

/// 검색어로 거른다. 대소문자는 가리지 않고, 공백만이면 전부 통과다. 서버
/// 검색이 아니라 기기에 있는 목록을 좁히는 것이라 글자가 들어 있는지만 본다.
bool matchesKeyword(String text, String keyword) {
  final trimmed = keyword.trim();
  if (trimmed.isEmpty) return true;
  return text.toLowerCase().contains(trimmed.toLowerCase());
}
