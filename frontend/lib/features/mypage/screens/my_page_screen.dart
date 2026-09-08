import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';

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
          // 로그인 화면으로 가는 임시 진입점. 회원가입은 로그인 화면의 링크로
          // 옮겼다. 마이페이지 화면 작업에서 로그인 여부에 따라 달라지는 실제
          // UI 로 바꾸고, 로그인 결과(true)도 로그인 상태 작업에서 받아 쓴다.
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            child: const Text(AuthStrings.login),
          ),
        ],
      ),
    );
  }
}
