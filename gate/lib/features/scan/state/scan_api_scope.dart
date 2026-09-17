import 'package:flutter/widgets.dart';

import '../data/scan_api.dart';

/// 스캔 화면들에 [ScanApi] 구현을 내려주는 InheritedWidget.
///
/// 구독이 아니라 읽기만 하므로 `initState` 에서도 부를 수 있다.
class ScanApiScope extends InheritedWidget {
  const ScanApiScope({super.key, required this.api, required super.child});

  final ScanApi api;

  static ScanApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ScanApiScope>();
    assert(scope != null, 'ScanApiScope 가 위젯 트리 위에 없습니다.');
    return scope!.api;
  }

  @override
  bool updateShouldNotify(ScanApiScope oldWidget) => api != oldWidget.api;
}
