import 'dart:math';

/// 가입·로그인 요청의 `X-Device-Id` 헤더 값.
///
/// 서버가 기기별로 로그인 세션(리프레시 토큰)을 관리하려면 기기마다 다른
/// 식별자가 필요하다. 없으면 폰을 잃어버렸을 때 그 기기만 끊을 수 없다.
///
/// 지금은 앱을 켤 때 한 번 만들어 켜져 있는 동안만 같은 값을 쓴다. 앱을 다시
/// 켜면 새 값이 된다. 기기에 저장해 두는 일은 토큰 저장과 묶여 있어 로그인
/// 작업에서 저장 방식과 함께 정한다. 그때는 [value] 만 저장소에서 읽도록 바꾼다.
class DeviceId {
  DeviceId._();

  /// 처음 읽을 때 한 번 만들어지고 그 뒤로는 같은 값이다.
  static final String value = generate();

  /// UUID v4 (예: `3f2b1c9e-8d4a-4b6f-9c1d-2e7a5b8c0d1f`). 36자라 서버 한계
  /// 64자 안에 든다.
  ///
  /// uuid 패키지를 붙이지 않은 이유: 필요한 건 무작위 문자열 하나라 표준 모양만
  /// 맞추면 되고, 그 정도는 몇 줄로 끝난다.
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // 7번째 바이트 윗자리에 버전(4), 9번째 바이트 윗자리에 변형(10xx)을 새긴다.
    // 이 두 자리가 있어야 표준 UUID 로 읽힌다.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
