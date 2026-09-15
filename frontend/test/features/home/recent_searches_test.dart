import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/home/constants.dart';
import 'package:timo/features/home/models/recent_searches.dart';

/// 최근 검색어 규칙. 화면·저장소와 떼어 놓고 목록만 본다.
void main() {
  test('새 검색어는 맨 앞에 들어간다', () {
    final recent = const RecentSearches(['빅뱅']).add('아이유');

    expect(recent.items, ['아이유', '빅뱅']);
  });

  test('이미 있는 검색어는 하나만 남기고 맨 앞으로 올린다', () {
    final recent = const RecentSearches(['빅뱅', '아이유', '리센느']).add('아이유');

    expect(recent.items, ['아이유', '빅뱅', '리센느']);
  });

  test('앞뒤 공백은 떼고, 공백만이면 넣지 않는다', () {
    const before = RecentSearches(['빅뱅']);

    expect(before.add('  아이유 ').items, ['아이유', '빅뱅']);
    expect(before.add('   '), before);
  });

  test('한도를 넘으면 오래된 것부터 떨어진다', () {
    var recent = const RecentSearches();
    for (var i = 0; i < HomeMetrics.recentSearchLimit + 2; i++) {
      recent = recent.add('검색어 $i');
    }

    expect(recent.items.length, HomeMetrics.recentSearchLimit);
    expect(recent.items.first, '검색어 ${HomeMetrics.recentSearchLimit + 1}');
    expect(recent.items, isNot(contains('검색어 0')));
    expect(recent.items, isNot(contains('검색어 1')));
  });

  test('하나만 지우면 나머지 순서는 그대로다', () {
    final recent = const RecentSearches(['아이유', '빅뱅', '리센느']).remove('빅뱅');

    expect(recent.items, ['아이유', '리센느']);
  });

  test('없는 검색어를 지워도 실패하지 않는다', () {
    const before = RecentSearches(['아이유']);

    expect(before.remove('없음'), before);
  });

  test('전체 삭제는 빈 목록이다', () {
    final recent = const RecentSearches(['아이유', '빅뱅']).clear();

    expect(recent.isEmpty, isTrue);
  });
}
