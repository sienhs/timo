import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';

/// 임시 홈. [MainShellScreen] 의 첫 번째 탭 본문이다.
///
/// Scaffold 를 두지 않는다 — 셸이 이미 Scaffold 와 하단 바를 들고 있고,
/// 여기서 하나 더 만들면 하단 바 위에 또 다른 화면이 얹힌 모양이 된다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('기능 화면은 features/ 아래에 만들고\nAppRoutes에 등록해서 연결하세요',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          // 홈 화면이 아직 비어 있어 예매 흐름으로 들어갈 길이 없다.
          // 공연 목록이 붙으면 목록의 공연 카드가 이 자리를 대신한다.
          OutlinedButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.zoneSelection),
            child: const Text('예매 화면 보기'),
          ),
        ],
      ),
    );
  }
}
