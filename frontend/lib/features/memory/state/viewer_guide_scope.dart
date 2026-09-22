import 'package:flutter/widgets.dart';

import '../data/viewer_guide_setting.dart';

/// 소장품 화면에 [ViewerGuideSetting] 을 내려주는 InheritedNotifier.
///
/// `TiltSettingScope` 와 같은 방식이다.
class ViewerGuideScope extends InheritedNotifier<ViewerGuideSetting> {
  const ViewerGuideScope({
    super.key,
    required ViewerGuideSetting setting,
    required super.child,
  }) : super(notifier: setting);

  /// 구독하지 않고 읽는다. 화면이 열릴 때 한 번 보고 결정할 뿐이라 값이 바뀌어도
  /// 다시 그릴 일이 없다.
  static ViewerGuideSetting read(BuildContext context) {
    final setting = context
        .getInheritedWidgetOfExactType<ViewerGuideScope>()
        ?.notifier;
    assert(setting != null, 'ViewerGuideScope 가 위젯 트리 위에 없습니다');
    return setting!;
  }
}
