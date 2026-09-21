import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_scopes.dart';
import 'package:timo/features/memory/screens/creator_screen.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/widgets/ui/glow_button.dart';
import 'package:timo/features/memory/widgets/creator/concert_card.dart';

void main() {
  testWidgets('concert step at 320x568 and large text has no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      withMemoryScopes(
        MaterialApp(
          theme: timoTheme(),
          home: MediaQuery(
            // Reduced motion: ambient loops (aurora, previews) render still
            // frames so pumpAndSettle can settle.
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
              disableAnimations: true,
            ),
            child: const CreatorScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1/${CreatorText.totalSteps}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // 카드를 고르면 초록 테두리가 서고, 시작은 아래 버튼 하나가 맡는다.
    await tester.tap(find.widgetWithText(ConcertCard, '빛으로 남은 밤'));
    await tester.pump();
    // 앱바 제목도 같은 문구라 버튼 쪽을 집는다.
    await tester.tap(
      find.widgetWithText(GlowButton, CreatorText.concertAction),
    );
    await tester.pumpAndSettle();
    expect(find.text('2/${CreatorText.totalSteps}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
