import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/widgets/viewer/immersive_video.dart';
import 'package:timo/features/memory/screens/immersive_video_screen.dart';

/// No video platform in unit tests, so the controller fails to initialise:
/// the fullscreen page must still open on hold and close after release.
void main() {
  testWidgets('hold opens the fullscreen page, release closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              height: 440,
              child: ImmersiveVideo(
                photo: const ColoredBox(color: Colors.green),
                videoUrl: 'assets/videos/missing.mp4',
                transition: const {},
                onDrag: (_) {},
                onFlip: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(ImmersiveVideo)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.byType(ImmersiveVideoPage), findsOneWidget);
    expect(find.text('공식 영상 준비 중'), findsOneWidget);
    await hold.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ImmersiveVideoPage), findsNothing);
    expect(find.text('공식 영상 준비 중'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
