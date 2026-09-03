import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'routes/app_routes.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D206', // TODO: 서비스 이름 정해지면 변경
      theme: AppTheme.light,
      // TODO: 발표용으로 결제 화면부터 시작한다. 다른 화면이 붙으면 AppRoutes.home으로 되돌린다.
      initialRoute: AppRoutes.payment,
      routes: AppRoutes.routes,
    );
  }
}
