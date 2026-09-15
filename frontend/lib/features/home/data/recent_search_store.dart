import 'package:shared_preferences/shared_preferences.dart';

/// 최근 검색어를 기기에 넣고 빼는 약속.
///
/// 앱에서는 [SharedPreferencesRecentSearchStore] 가 기기 설정 저장소에 남기고,
/// 테스트는 [InMemoryRecentSearchStore] 를 꽂는다. 위젯 테스트는 플러그인
/// (플랫폼 채널)을 못 쓰기 때문이다 — 인증의 `TokenStorage` 와 같은 분리다.
///
/// 보안 저장소(`TokenStorage`)를 같이 쓰지 않는다. 검색어는 민감 정보가 아니고,
/// 저쪽은 로그아웃할 때 비우는 자리라 검색어까지 딸려 지워진다.
///
/// 규칙(최신순 · 중복 제거 · 최대 개수)은 여기 없다. `RecentSearches` 가 정하고,
/// 저장소는 받은 목록을 그대로 남긴다.
abstract class RecentSearchStore {
  /// 저장된 목록. 없으면 빈 목록.
  Future<List<String>> load();

  Future<void> save(List<String> keywords);
}

/// 기기 설정 저장소(shared_preferences)에 넣는 진짜 구현.
class SharedPreferencesRecentSearchStore implements RecentSearchStore {
  SharedPreferencesRecentSearchStore();

  static const key = 'search.recent';

  @override
  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? const [];
  }

  @override
  Future<void> save(List<String> keywords) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, keywords);
  }
}

/// 메모리에만 두는 구현. 테스트와, 플러그인이 없는 자리(위젯 테스트의 App)에서
/// 쓴다. 앱을 끄면 사라진다.
class InMemoryRecentSearchStore implements RecentSearchStore {
  InMemoryRecentSearchStore([List<String>? initial])
    : _keywords = [...?initial];

  List<String> _keywords;

  /// 테스트가 "무엇이 저장됐나" 를 들여다볼 때 쓴다.
  List<String> get keywords => List.unmodifiable(_keywords);

  @override
  Future<List<String>> load() async => List.unmodifiable(_keywords);

  @override
  Future<void> save(List<String> keywords) async => _keywords = [...keywords];
}
