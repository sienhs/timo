import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 소장품 화면의 조작법 안내를 본 적이 있는지를 기기에 넣고 빼는 약속.
///
/// `TiltSettingStore` 와 같은 분리다 — 앱은 기기 설정 저장소 구현을 쓰고,
/// 위젯 테스트는 플러그인(플랫폼 채널)을 못 써서 메모리 구현을 꽂는다.
abstract class ViewerGuideStore {
  /// 본 적이 있는가. 한 번도 기록한 적이 없으면 null.
  Future<bool?> load();

  Future<void> save(bool seen);
}

/// 기기 설정 저장소(shared_preferences)에 넣는 진짜 구현.
class SharedPreferencesViewerGuideStore implements ViewerGuideStore {
  SharedPreferencesViewerGuideStore();

  static const key = 'memory.viewerGuideSeen';

  @override
  Future<bool?> load() async =>
      (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> save(bool seen) async =>
      (await SharedPreferences.getInstance()).setBool(key, seen);
}

/// 메모리에만 두는 구현. 테스트와, 플러그인이 없는 자리에서 쓴다.
class InMemoryViewerGuideStore implements ViewerGuideStore {
  InMemoryViewerGuideStore([this._seen]);

  bool? _seen;
  bool? get seen => _seen;

  @override
  Future<bool?> load() async => _seen;

  @override
  Future<void> save(bool seen) async => _seen = seen;
}

/// 조작법 안내를 이미 봤는가. 앱에 하나만 두고 소장품 화면이 본다.
///
/// 소장품 화면은 "좌우로 밀어 뒤집기·길게 눌러 영상 보기" 를 화면에 늘 적어
/// 두는 대신 **처음 열 때 한 번** 안내로 보여준다. 늘 적어 두면 카드 아래가
/// 설명으로 차서 무엇을 보는 화면인지 흐려지고, 두 번째부터는 읽지도 않는다.
class ViewerGuideSetting extends ChangeNotifier {
  /// [alreadySeen] 은 테스트용이다 — 안내가 확정 버튼을 가리면 안 되는 테스트가
  /// 처음부터 본 것으로 시작한다. 앱은 넘기지 않고 [restore] 로 읽는다.
  ViewerGuideSetting(this._store, {bool alreadySeen = false})
    : _seen = alreadySeen;

  final ViewerGuideStore _store;

  bool _seen;
  bool get seen => _seen;

  /// 앱이 뜰 때 한 번. 저장된 값이 없으면 "아직 안 봤다" 그대로 둔다.
  Future<void> restore() async {
    final saved = await _store.load();
    if (saved == null || saved == _seen) return;
    _seen = saved;
    notifyListeners();
  }

  /// 저장을 기다리지 않고 바로 알린다. 닫은 안내가 저장이 늦다고 다시 뜨면
  /// 안 된다.
  Future<void> markSeen() async {
    if (_seen) return;
    _seen = true;
    notifyListeners();
    await _store.save(true);
  }
}
