import 'package:flutter/widgets.dart';

import '../data/alarm_api.dart';

/// 공연 상세 화면에 [AlarmApi] 구현을 내려주는 InheritedWidget.
/// 앱은 맨 위에서 진짜 구현을 하나 만들어 담고, 화면은 요청을 보낼 때 꺼내 쓴다.
class AlarmApiScope extends InheritedWidget {
  const AlarmApiScope({super.key, required this.api, required super.child});

  final AlarmApi api;

  /// 없으면 null. 공연 상세는 스코프 없이 띄우는 테스트가 많고, 알림 버튼 상태를
  /// 못 불러오는 것은 화면이 못 뜨는 것과 달리 넘어갈 만한 일이다.
  static AlarmApi? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AlarmApiScope>()?.api;

  @override
  bool updateShouldNotify(AlarmApiScope oldWidget) => api != oldWidget.api;
}
