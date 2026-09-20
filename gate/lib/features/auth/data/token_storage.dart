/// 인증이 기기에 저장하는 값들의 키. 한 곳에 모아 두어 넣는 쪽과 꺼내는 쪽이
/// 어긋나지 않게 한다.
///
/// 저장소 자체(넣고 빼는 일)는 `core/storage/device_storage.dart` 로 올라갔다 —
/// 공연 선택도 같은 저장소를 쓴다. 여기 남은 것은 인증만 아는 키 이름이다.
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
