import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_scopes.dart';
import 'package:timo/features/memory/screens/creator_screen.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/widgets/creator/concert_card.dart';

void main() {
  testWidgets('selecting a concert enables the next step with live motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      withMemoryScopes(
        MaterialApp(theme: timoTheme(), home: const CreatorScreen()),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('1/5'), findsOneWidget);
    // Each concert card carries its own "NFT 소장품 만들기" action.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ConcertCard, '빛으로 남은 밤'),
        matching: find.text(CreatorText.concertAction),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('2/5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
