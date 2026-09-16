import 'package:flutter/widgets.dart';

import 'creation_job.dart';

/// 앱 전체에 '제작중' job 을 내려주는 InheritedNotifier.
///
/// 제작 화면이 job 을 시작하고, 완료 배너(앱 최상단)가 결과를 본다. 둘이 서로
/// 다른 라우트라 둘보다 위에서 하나를 들고 있어야 한다. `BookingScope` 가
/// 좌석 선택 → 결제 사이에서 하는 일과 같다.
class CreationJobScope extends InheritedNotifier<CreationJob> {
  const CreationJobScope({
    super.key,
    required CreationJob job,
    required super.child,
  }) : super(notifier: job);

  /// job 이 알릴 때 같이 리빌드된다. 진행 상태를 그리는 자리에서 쓴다.
  static CreationJob of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CreationJobScope>();
    assert(scope != null, 'CreationJobScope 가 위젯 트리 위에 없습니다');
    return scope!.notifier!;
  }

  /// 구독하지 않고 job 만 꺼낸다. 시작·확인처럼 부르기만 하는 자리용.
  static CreationJob read(BuildContext context) {
    final job = context.getInheritedWidgetOfExactType<CreationJobScope>()?.notifier;
    assert(job != null, 'CreationJobScope 가 위젯 트리 위에 없습니다');
    return job!;
  }
}
