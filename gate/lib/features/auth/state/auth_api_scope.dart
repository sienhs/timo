import 'package:flutter/widgets.dart';

import '../data/auth_api.dart';

/// 인증 화면·버튼에 [AuthApi] 구현을 내려주는 InheritedWidget.
///
/// 앱은 맨 위에서 구현 하나를 만들어 여기에 담고, 로그인 화면·로그아웃 버튼은
/// 요청을 보낼 때 [of] 로 꺼내 쓴다. 화면 생성자에 `api` 를 직접 넘기면 그쪽이
/// 우선이라, 화면 단위 테스트는 스코프 없이 목을 바로 넣는다.
///
/// 스캔 쪽 ScanApiScope 와 같은 방식이다. 앱이 켜져 있는 동안 바뀌지 않는 구현
/// 하나를 내려줄 뿐이라 평범한 InheritedWidget 으로 충분하다.
class AuthApiScope extends InheritedWidget {
  const AuthApiScope({super.key, required this.api, required super.child});

  final AuthApi api;

  /// 구독(dependOn…)이 아니라 읽기만 한다. 값이 바뀌지 않으므로 리빌드를
  /// 걸어 둘 이유가 없다.
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
