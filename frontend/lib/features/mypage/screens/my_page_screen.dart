import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_api_scope.dart';
import '../../auth/state/auth_session.dart';
import '../../auth/state/auth_session_scope.dart';

/// 임시 마이페이지. 하단 바의 두 번째 탭이 가리키는 자리다.
/// 실제 내용은 마이페이지 화면 작업에서 채운다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  /// 로그아웃. 기기 토큰을 먼저 지우고, 서버에는 알려만 준다.
  ///
  /// 순서가 중요하다. 세션을 비우면 리프레시 토큰이 사라지므로 서버에 보낼 값을
  /// 먼저 꺼내 둔다. 세션을 비우는 순간 화면이 '로그인' 버튼으로 바뀌어 사용자는
  /// 서버 응답을 기다리지 않는다.
  ///
  /// 서버에 못 알려도(네트워크 끊김) 로그아웃은 된 것으로 친다. 기기 토큰은 이미
  /// 지웠고, 서버 쪽 세션은 30일 뒤 저절로 만료된다. 여기서 실패를 알려 봐야
  /// 사용자가 할 수 있는 일이 없다.
  ///
  /// 세션([AuthSession.signOut]) 안에 서버 호출을 넣지 않은 이유: 그 메서드는
  /// 401 을 받은 인터셉터도 부르는데, 그때는 토큰이 이미 안 통하는 상태라 서버에
  /// 알릴 게 없다. 로그아웃 진입점이 늘면 이 세 단계를 헬퍼로 뺀다.
  Future<void> _logout(BuildContext context, AuthSession session) async {
    // await 앞에서 context 를 다 쓴다. 뒤에서 쓰면 화면이 사라진 뒤일 수 있다.
    final api = AuthApiScope.of(context);
    final refreshToken = session.refreshToken;

    await session.signOut();

    if (refreshToken == null) return;
    try {
      await api.logout(refreshToken);
    } on ApiException {
      // 서버에 못 알린 것뿐이다. 위 설명대로 무시한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로그인·로그아웃이 일어나면 이 화면도 다시 그려진다. 스코프 없이 셸만
    // 띄우는 테스트에서는 null 이라 로그아웃 상태로 본다.
    final session = AuthSessionScope.maybeOf(context);
    final isLoggedIn = session?.isLoggedIn ?? false;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('마이페이지는 준비 중이에요.'),
          const SizedBox(height: 20),
          // 로그인 화면으로 가는 임시 진입점. 로그인 상태면 로그아웃 버튼이 된다.
          // 지금은 로그인 여부를 눈으로 확인할 수 있는 유일한 자리다. 마이페이지
          // 화면 작업에서 로그인 여부에 따라 달라지는 실제 UI 로 바꾼다.
          OutlinedButton(
            onPressed: isLoggedIn
                ? () => _logout(context, session!)
                : () => Navigator.pushNamed(context, AppRoutes.login),
            child: Text(isLoggedIn ? AuthStrings.logout : AuthStrings.login),
          ),
        ],
      ),
    );
  }
}
