import 'package:flutter/material.dart';

/// 임시 홈 화면. 각 기능 화면이 만들어지면 여기서 진입점을 연결한다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: const Center(
        child: Text('기능 화면은 features/ 아래에 만들고\nAppRoutes에 등록해서 연결하세요'),
      ),
    );
  }
}
