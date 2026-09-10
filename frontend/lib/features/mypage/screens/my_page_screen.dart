import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';

/// 임시 마이페이지. 하단 바의 두 번째 탭이 가리키는 자리다.
/// 실제 내용은 마이페이지 화면 작업에서 채운다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

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
                ? session!.signOut
                : () => Navigator.pushNamed(context, AppRoutes.login),
            child: Text(isLoggedIn ? AuthStrings.logout : AuthStrings.login),
          ),
        ],
      ),
    );
  }
}
