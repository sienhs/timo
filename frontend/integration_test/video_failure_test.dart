import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:timo/features/memory/widgets/viewer/immersive_video.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Widget shell(String url) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 280,
          height: 440,
          child: ImmersiveVideo(
            photo: const ColoredBox(color: Colors.green),
            videoUrl: url,
            transition: const {},
            onDrag: (_) {},
            onFlip: () {},
          ),
        ),
      ),
    ),
  );
  testWidgets('video pauses on app background and resets on release', (
    tester,
  ) async {
    await tester.pumpWidget(shell('assets/videos/official_demo.mp4'));
    await tester.pump(const Duration(seconds: 3));
    final hold = await tester.startGesture(
      tester.getCenter(find.byType(ImmersiveVideo)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(VideoPlayer), findsOneWidget);
    final controller = tester
        .widget<VideoPlayer>(find.byType(VideoPlayer))
        .controller;
    expect(controller.value.isPlaying, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.value.isPlaying, false);
    await hold.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(VideoPlayer), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'missing video shows Korean unavailable state and returns to photo',
    (tester) async {
      await tester.pumpWidget(shell('assets/videos/missing.mp4'));
      await tester.pump(const Duration(seconds: 2));
      final hold = await tester.startGesture(
        tester.getCenter(find.byType(ImmersiveVideo)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('공식 영상 준비 중'), findsOneWidget);
      await hold.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('공식 영상 준비 중'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
