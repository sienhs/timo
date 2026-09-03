import 'package:flutter_test/flutter_test.dart';

import 'package:timo/app.dart';
import 'package:timo/features/payment/screens/payment_screen.dart';

void main() {
  testWidgets('앱 실행 시 결제 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.byType(PaymentScreen), findsOneWidget);
  });
}
