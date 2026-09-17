import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 로그인 정보(토큰·회원 번호·기기 식별자)를 기기에 넣고 빼는 약속.
/// 팬 앱의 같은 파일과 같다.
///
/// 앱에서는 [SecureTokenStorage] 가 안드로이드 Keystore 에 암호화해서 저장하고,
/// 테스트에서는 [InMemoryTokenStorage] 를 꽂는다. 위젯 테스트는 플러그인(플랫폼
/// 채널)을 못 쓰기 때문에, 이 분리가 없으면 로그인 상태가 얽힌 화면을 테스트할
/// 수 없다.
///
/// 값은 전부 문자열이다. 숫자·시각은 쓰는 쪽([AuthSession])이 문자열로 바꿔
/// 넣고 읽을 때 다시 해석한다.
abstract class TokenStorage {
  /// 없으면 null.
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  /// 없는 키를 지워도 실패하지 않는다.
  Future<void> delete(String key);
}

/// 저장 키. 한 곳에 모아 두어 넣는 쪽과 꺼내는 쪽이 어긋나지 않게 한다.
class TokenStorageKeys {
  TokenStorageKeys._();

  static const memberId = 'auth.memberId';
  static const accessToken = 'auth.accessToken';
  static const refreshToken = 'auth.refreshToken';

  /// ISO 8601 문자열. 서버는 남은 초를 주지만, 저장할 때는 절대 시각으로 바꿔야
  /// 앱을 다시 켰을 때 얼마나 남았는지 알 수 있다.
  static const accessTokenExpiresAt = 'auth.accessTokenExpiresAt';

  /// 기기 식별자. 로그인 정보가 아니라 로그아웃해도 지우지 않는다. 서버가
  /// (회원, 기기) 한 쌍으로 세션을 관리해서, 로그아웃 뒤 다시 로그인해도 같은
  /// 기기로 보여야 세션이 둘로 갈리지 않는다.
  static const deviceId = 'device.id';
}

/// 기기 보안 저장소(flutter_secure_storage)에 넣는 진짜 구현.
class SecureTokenStorage implements TokenStorage {
  /// [storage] 는 테스트에서 가짜를 넣기 위해 받는다. 앱에서는 기본 설정을 쓴다.
  SecureTokenStorage([FlutterSecureStorage? storage])
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
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([Map<String, String>? initial])
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
