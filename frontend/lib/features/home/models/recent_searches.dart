import 'package:flutter/foundation.dart';

import '../constants.dart';

/// 최근 검색어 목록. 최신이 앞이다. 규칙(중복 제거 · 최대 개수)을 여기 한 곳에
/// 두고, 불변 객체라 바꿀 때마다 새 객체를 돌려준다.
@immutable
class RecentSearches {
  const RecentSearches([this.items = const []]);

  final List<String> items;

  bool get isEmpty => items.isEmpty;

  /// 검색어를 맨 앞에 넣는다. 이미 있으면 그 자리에서 빼서 앞으로 올리고,
  /// [HomeMetrics.recentSearchLimit] 을 넘는 오래된 것은 떨어진다.
  RecentSearches add(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return this;
    final next = [trimmed, ...items.where((item) => item != trimmed)];
    return RecentSearches(
      List.unmodifiable(next.take(HomeMetrics.recentSearchLimit)),
    );
  }

  RecentSearches remove(String keyword) =>
      RecentSearches(List.unmodifiable(items.where((item) => item != keyword)));

  RecentSearches clear() => const RecentSearches();

  @override
  bool operator ==(Object other) =>
      other is RecentSearches && listEquals(other.items, items);

  @override
  int get hashCode => Object.hashAll(items);
}
