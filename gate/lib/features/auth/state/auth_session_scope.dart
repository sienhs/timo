import 'package:flutter/widgets.dart';

import 'auth_session.dart';

/// 앱 전체에 [AuthSession] 을 내려주는 InheritedNotifier.
///
/// 로그인 여부에 따라 달라지는 자리(앱의 첫 화면 선택)는 [of] 로 구독해
/// 로그인·로그아웃 때 다시 그려지고, 버튼 콜백처럼 값만 쓰는 자리는 [read] 로
/// 꺼낸다.
class AuthSessionScope extends InheritedNotifier<AuthSession> {
  const AuthSessionScope({
    super.key,
    required AuthSession session,
    required super.child,
  }) : super(notifier: session);

  /// 세션이 바뀌면 호출한 위젯도 함께 다시 그려진다. build 안에서 쓴다.
  static AuthSession of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AuthSessionScope>();
    assert(scope != null, 'AuthSessionScope 가 위젯 트리 위에 없습니다');
    return scope!.notifier!;
  }

  /// 구독하지 않고 세션만 꺼낸다. 콜백에서 로그인·로그아웃을 부를 때 쓴다.
  static AuthSession read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthSessionScope>();
    assert(scope != null, 'AuthSessionScope 가 위젯 트리 위에 없습니다');
    return scope!.notifier!;
  }
}
