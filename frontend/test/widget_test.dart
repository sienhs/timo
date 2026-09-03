import 'package:flutter_test/flutter_test.dart';

import 'package:timo/app.dart';
import 'package:timo/features/booking/screens/zone_selection_screen.dart';

void main() {
  testWidgets('앱 실행 시 좌석 선택 화면이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    // 좌석 선택 → 결제 → 완료가 이어졌으므로 흐름의 처음에서 시작한다.
    // 홈 화면은 따로 설계 예정이다.
    expect(find.byType(ZoneSelectionScreen), findsOneWidget);
  });
}
