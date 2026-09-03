import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:timo/features/payment/constants.dart';
import 'package:timo/features/payment/screens/payment_complete_screen.dart';
import 'package:timo/features/payment/screens/payment_screen.dart';
import 'package:timo/routes/app_routes.dart';

/// 폰 화면 크기. 이보다 좁아지면 레이아웃이 깨지는지 확인하는 기준이 된다.
const _phoneSize = Size(375, 812);

Future<void> _pumpApp(WidgetTester tester, String initialRoute) async {
  await tester.binding.setSurfaceSize(_phoneSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(initialRoute: initialRoute, routes: AppRoutes.routes),
  );
}

void main() {
  testWidgets('결제 화면에 주문 요약과 합계 금액이 표시된다', (WidgetTester tester) async {
    await _pumpApp(tester, AppRoutes.payment);

    expect(find.text(PaymentConstants.sampleOrder.concertTitle), findsOneWidget);
    expect(find.text(PaymentConstants.totalLabel), findsOneWidget);
    expect(find.text('189,000원'), findsOneWidget);
  });

  testWidgets('결제 버튼을 누르면 완료 화면으로 전환된다', (WidgetTester tester) async {
    await _pumpApp(tester, AppRoutes.payment);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentCompleteScreen), findsOneWidget);
    expect(find.byType(PaymentScreen), findsNothing);
  });

  testWidgets('완료 화면에 성공 문구와 예약 정보가 표시된다', (WidgetTester tester) async {
    await _pumpApp(tester, AppRoutes.paymentComplete);

    expect(find.text(PaymentConstants.completeTitle), findsOneWidget);
    expect(find.text(PaymentConstants.issuingBadgeLabel), findsOneWidget);
    expect(find.text(PaymentConstants.seatLabel), findsOneWidget);
    expect(find.text(PaymentConstants.viewTicketLabel), findsOneWidget);
    expect(find.text(PaymentConstants.goHomeLabel), findsOneWidget);
  });
}
