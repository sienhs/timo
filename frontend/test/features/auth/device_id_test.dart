import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/auth/data/device_id.dart';

void main() {
  /// UUID v4 모양: 8-4-4-4-12 자리 16진수, 세 번째 묶음은 4로 시작, 네 번째
  /// 묶음은 8·9·a·b 중 하나로 시작.
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('표준 UUID v4 모양이고 서버 한계(64자) 안이다', () {
    final id = DeviceId.generate();

    expect(id, matches(uuidV4));
    expect(id.length, 36);
  });

  test('만들 때마다 다른 값이 나온다', () {
    expect(DeviceId.generate(), isNot(DeviceId.generate()));
  });

  test('앱이 켜져 있는 동안은 같은 값을 돌려준다', () {
    expect(DeviceId.value, DeviceId.value);
    expect(DeviceId.value, matches(uuidV4));
  });
}
