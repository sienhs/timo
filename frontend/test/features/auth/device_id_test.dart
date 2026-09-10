import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/auth/data/device_id.dart';
import 'package:timo/features/auth/data/token_storage.dart';

void main() {
  /// UUID v4 모양: 8-4-4-4-12 자리 16진수, 세 번째 묶음은 4로 시작, 네 번째
  /// 묶음은 8·9·a·b 중 하나로 시작.
  final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(DeviceId.reset);

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

  group('기기 저장소와 이어지면', () {
    test('저장된 식별자가 있으면 그걸 쓴다', () async {
      final storage = InMemoryTokenStorage({
        TokenStorageKeys.deviceId: 'saved-device-id',
      });

      await DeviceId.restore(storage);

      expect(DeviceId.value, 'saved-device-id');
    });

    test('없으면 새로 만들어 저장한다. 다음에 켤 때 같은 값이 나온다', () async {
      final storage = InMemoryTokenStorage();

      await DeviceId.restore(storage);
      final first = DeviceId.value;

      expect(first, matches(uuidV4));
      expect(storage.values[TokenStorageKeys.deviceId], first);

      // 앱을 다시 켠 상황.
      DeviceId.reset();
      await DeviceId.restore(storage);
      expect(DeviceId.value, first);
    });
  });
}
