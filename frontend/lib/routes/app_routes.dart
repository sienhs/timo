import 'package:flutter/material.dart';

import '../features/home/screens/home_screen.dart';
import '../features/payment/constants.dart';
import '../features/payment/screens/payment_complete_screen.dart';
import '../features/payment/screens/payment_screen.dart';

/// 화면 라우트 등록부.
/// 새 화면을 만들면 1) 이름 상수 추가, 2) routes 맵에 builder 등록.
/// 이동은 Navigator.pushNamed(context, AppRoutes.xxx) 사용.
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const payment = '/payment';
  static const paymentComplete = '/payment/complete';

  static final Map<String, WidgetBuilder> routes = {
    home: (_) => const HomeScreen(),
    // 서버 연동 전까지 더미 주문을 주입한다. 화면은 출처를 모른다.
    payment: (_) => PaymentScreen(order: PaymentConstants.sampleOrder),
    paymentComplete: (_) =>
        PaymentCompleteScreen(order: PaymentConstants.sampleOrder),
  };
}
