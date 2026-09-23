import 'dart:math';

import 'package:flutter/foundation.dart';

import 'token_storage.dart';

/// 가입·로그인 요청의 `X-Device-Id` 헤더 값. 서버가 (회원, 기기) 한 쌍으로 세션을
/// 관리하므로 같은 기기에서는 늘 같아야 한다. 앱을 켤 때 [restore] 로 기기
/// 저장소에서 읽고 처음이면 만들어 저장한다. 로그아웃해도 지우지 않는다.
class DeviceId {
  DeviceId._();

  static String? _value;

  /// 현재 기기 식별자. [restore] 전에 읽히면 즉석에서 만들어 둔다.
  static String get value => _value ??= generate();

  /// 저장된 식별자를 되살린다. 없으면 새로 만들어 저장한다.
  static Future<void> restore(TokenStorage storage) async {
    final saved = await storage.read(TokenStorageKeys.deviceId);
    if (saved != null && saved.isNotEmpty) {
      _value = saved;
      return;
    }
    final fresh = generate();
    _value = fresh;
    await storage.write(TokenStorageKeys.deviceId, fresh);
  }

  /// 테스트가 서로 영향을 주지 않도록 되살린 값을 잊는다.
  @visibleForTesting
  static void reset() => _value = null;

  /// UUID v4 (예: `3f2b1c9e-8d4a-4b6f-9c1d-2e7a5b8c0d1f`). 36자라 서버 한계
  /// 64자 안에 든다. 무작위 문자열 하나면 되어 uuid 패키지는 붙이지 않았다.
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
