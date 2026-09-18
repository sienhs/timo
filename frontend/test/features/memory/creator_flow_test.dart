import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_scopes.dart';
import 'package:timo/features/memory/screens/creator_screen.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/widgets/creator/concert_card.dart';
import 'package:timo/features/memory/widgets/creator/selection_tile.dart';

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

  testWidgets('the add-photo tile offers gallery and camera sources', (
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
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ConcertCard, '빛으로 남은 밤'),
        matching: find.text(CreatorText.concertAction),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // 배경 단계의 "+" 타일. 갤러리 하나로 바로 열지 않고 출처를 먼저 묻는다.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is SelectionTile && w.label == CreatorText.addPhotoLabel,
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text(CreatorText.photoSourceTitle), findsOneWidget);
    expect(find.text(CreatorText.galleryLabel), findsOneWidget);
    expect(find.text(CreatorText.cameraLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
