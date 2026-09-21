import 'package:flutter/widgets.dart';

import '../data/tilt_setting.dart';

/// 소장품 화면들에 [TiltSetting] 을 내려주는 InheritedNotifier.
///
/// `TicketStoreScope` 와 같은 방식이다. 값이 바뀌면 [of] 로 읽은 화면이 함께
/// 리빌드되어 카드가 곧바로 센서를 놓거나 다시 잡는다.
class TiltSettingScope extends InheritedNotifier<TiltSetting> {
  const TiltSettingScope({
    super.key,
    required TiltSetting setting,
    required super.child,
  }) : super(notifier: setting);

  static TiltSetting of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TiltSettingScope>();
    assert(scope != null, 'TiltSettingScope 가 위젯 트리 위에 없습니다');
    return scope!.notifier!;
  }
}
