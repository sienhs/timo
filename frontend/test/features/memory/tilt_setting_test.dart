import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/tilt_setting.dart';

void main() {
  test('고른 적이 없으면 켜진 채로 시작한다', () async {
    final setting = TiltSetting(InMemoryTiltSettingStore());
    expect(setting.enabled, isTrue);
    await setting.restore();
    expect(setting.enabled, isTrue);
  });

  test('저장된 값이 있으면 그대로 켠다', () async {
    final setting = TiltSetting(InMemoryTiltSettingStore(false));
    var notified = 0;
    setting.addListener(() => notified++);
    await setting.restore();
    expect(setting.enabled, isFalse);
    expect(notified, 1);
  });

  test('끄면 기기에 남아 다음 실행에도 꺼져 있다', () async {
    final store = InMemoryTiltSettingStore();
    await TiltSetting(store).toggle();
    expect(store.enabled, isFalse);

    final next = TiltSetting(store);
    await next.restore();
    expect(next.enabled, isFalse);
  });

  test('저장을 기다리지 않고 바로 알린다', () {
    final setting = TiltSetting(InMemoryTiltSettingStore());
    var notified = 0;
    setting.addListener(() => notified++);
    setting.toggle();
    expect(setting.enabled, isFalse);
    expect(notified, 1);
  });
}
