import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';

/// 임시 마이페이지. 하단 바의 두 번째 탭이 가리키는 자리다.
/// 실제 내용은 마이페이지 화면 작업에서 채운다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('마이페이지는 준비 중이에요.'),
          const SizedBox(height: 20),
          // 로그인 화면이 생기기 전까지의 임시 진입점. 로그인 화면이 생기면
          // 그쪽 '회원가입' 링크로 옮기고 이 버튼은 지운다.
          OutlinedButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.signupPhone),
            child: const Text('회원가입'),
          ),
        ],
      ),
    );
  }
}
