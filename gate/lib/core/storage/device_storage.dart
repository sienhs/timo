import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 앱을 껐다 켜도 남아야 하는 값을 기기에 넣고 빼는 약속.
///
/// 앱에서는 [SecureDeviceStorage] 가 안드로이드 Keystore 에 암호화해서
/// 저장하고, 테스트에서는 [InMemoryDeviceStorage] 를 꽂는다. 위젯 테스트는
/// 플러그인(플랫폼 채널)을 못 쓰기 때문에, 이 분리가 없으면 저장 상태가 얽힌
/// 화면을 테스트할 수 없다.
///
/// 원래 인증 기능 안의 `TokenStorage` 였다. 검표할 공연을 기억하는 일
/// (`SelectedConcertStorage`)이 **같은 이유로** 같은 저장소를 쓰게 되어 여기로
/// 올렸다. 두 기능이 각자 저장소를 열면 테스트에서 갈아끼울 자리도 둘이 된다.
///
/// 값은 전부 문자열이다. 숫자·시각은 쓰는 쪽이 문자열로 바꿔 넣고 읽을 때 다시
/// 해석한다. 키는 각 기능이 자기 파일에 모아 둔다.
abstract class DeviceStorage {
  /// 없으면 null.
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  /// 없는 키를 지워도 실패하지 않는다.
  Future<void> delete(String key);
}

/// 기기 보안 저장소(flutter_secure_storage)에 넣는 진짜 구현.
class SecureDeviceStorage implements DeviceStorage {
  /// [storage] 는 테스트에서 가짜를 넣기 위해 받는다. 앱에서는 기본 설정을 쓴다.
  SecureDeviceStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 메모리에만 두는 구현. 테스트와, 플러그인이 없는 자리(위젯 테스트의 App)에서
/// 쓴다. 앱을 끄면 사라진다.
class InMemoryDeviceStorage implements DeviceStorage {
  InMemoryDeviceStorage([Map<String, String>? initial])
    : _values = {...?initial};

  final Map<String, String> _values;

  /// 테스트가 "무엇이 저장됐나" 를 들여다볼 때 쓴다.
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
