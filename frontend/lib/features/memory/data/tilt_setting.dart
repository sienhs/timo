import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 소장품 카드가 기기 기울임(자이로·중력)을 따라 움직일지 말지를 기기에 넣고
/// 빼는 약속.
///
/// `RecentSearchStore` 와 같은 분리다 — 앱은 기기 설정 저장소 구현을 쓰고,
/// 위젯 테스트는 플러그인(플랫폼 채널)을 못 써서 메모리 구현을 꽂는다.
abstract class TiltSettingStore {
  /// 저장된 값. 한 번도 고른 적이 없으면 null.
  Future<bool?> load();

  Future<void> save(bool enabled);
}

/// 기기 설정 저장소(shared_preferences)에 넣는 진짜 구현.
class SharedPreferencesTiltSettingStore implements TiltSettingStore {
  SharedPreferencesTiltSettingStore();

  static const key = 'memory.tiltBySensor';

  @override
  Future<bool?> load() async =>
      (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> save(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(key, enabled);
}

/// 메모리에만 두는 구현. 테스트와, 플러그인이 없는 자리에서 쓴다.
class InMemoryTiltSettingStore implements TiltSettingStore {
  InMemoryTiltSettingStore([this._enabled]);

  bool? _enabled;
  bool? get enabled => _enabled;

  @override
  Future<bool?> load() async => _enabled;

  @override
  Future<void> save(bool enabled) async => _enabled = enabled;
}

/// 기울임 효과를 켤지 말지. 앱에 하나만 두고 화면들이 같은 값을 본다.
///
/// 저장을 기다리지 않고 바로 알린다. 버튼을 누른 순간 카드가 반응해야 하고,
/// 저장이 늦거나 실패해도 이번 실행의 화면은 고른 대로 움직이는 편이 낫다.
class TiltSetting extends ChangeNotifier {
  TiltSetting(this._store);

  final TiltSettingStore _store;

  /// 처음 켠 사람에게는 켜진 상태를 보여준다 — 이 기능이 소장품의 핵심이다.
  bool _enabled = true;
  bool get enabled => _enabled;

  /// 앱이 뜰 때 한 번. 저장된 값이 없으면 기본값 그대로 둔다.
  Future<void> restore() async {
    final saved = await _store.load();
    if (saved == null || saved == _enabled) return;
    _enabled = saved;
    notifyListeners();
  }

  Future<void> toggle() async {
    _enabled = !_enabled;
    notifyListeners();
    await _store.save(_enabled);
  }
}
