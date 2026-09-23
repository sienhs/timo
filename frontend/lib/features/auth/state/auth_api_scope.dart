import 'package:flutter/widgets.dart';

import '../data/auth_api.dart';

/// 인증 화면들에 [AuthApi] 구현을 내려주는 InheritedWidget. 화면 생성자에 `api`
/// 를 직접 넘기면 그쪽이 우선이라 화면 단위 테스트는 스코프 없이 목을 넣는다.
/// 앱이 켜진 동안 바뀌지 않는 구현 하나라 InheritedNotifier 가 아니어도 된다.
class AuthApiScope extends InheritedWidget {
  const AuthApiScope({super.key, required this.api, required super.child});

  final AuthApi api;

  /// 요청을 보내는 자리(버튼 콜백)에서 꺼낸다. 값이 바뀌지 않으므로 구독하지
  /// 않고 읽기만 한다.
  static AuthApi of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AuthApiScope>();
    assert(
      scope != null,
      'AuthApiScope 가 위젯 트리 위에 없습니다. App 처럼 MaterialApp 을 '
      'AuthApiScope 로 감싸거나, 화면 생성자에 api 를 직접 넘기세요.',
    );
    return scope!.api;
  }

  @override
  bool updateShouldNotify(AuthApiScope oldWidget) => api != oldWidget.api;
}
