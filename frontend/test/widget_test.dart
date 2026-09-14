import 'package:flutter_test/flutter_test.dart';

import 'package:timo/app.dart';
import 'package:timo/features/home/data/mock_home_api.dart';
import 'package:timo/features/shell/screens/main_shell_screen.dart';

void main() {
  testWidgets('앱 실행 시 하단 바를 두른 홈 셸이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(
      const App(homeApi: MockHomeApi(latency: Duration.zero)),
    );

    expect(find.byType(MainShellScreen), findsOneWidget);
  });
}
