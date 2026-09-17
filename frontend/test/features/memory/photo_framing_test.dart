import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/widgets/creator/photo_frame.dart';
import 'package:timo/features/memory/models/photo_framing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late String source;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const pipeline = MethodChannel('timo/image_pipeline');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    folder = await Directory.systemTemp.createTemp('timo_framing_');
    source = '${folder.path}/source.png';
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * 100, 0, 100, 100),
        Paint()..color = [Colors.red, Colors.green, Colors.blue][i],
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 100);
    picture.dispose();
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File(source).writeAsBytes(data.buffer.asUint8List());
    image.dispose();
    messenger.setMockMethodCallHandler(paths, (_) async => folder.path);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(paths, null);
    messenger.setMockMethodCallHandler(pipeline, null);
    debugDefaultTargetPlatformOverride = null;
    await folder.delete(recursive: true);
  });

  test(
    'extreme pans and zooms cover the frame for every source orientation',
    () {
      const frame = Size(900, 1400);
      for (final size in [
        const Size(4000, 600),
        const Size(500, 4000),
        const Size(900, 1400),
      ]) {
        for (final scale in [1.0, 1.7, 3.0]) {
          for (final edge in [-1.0, 0.0, 1.0]) {
            final rect = PhotoFraming(
              scale: scale,
              x: edge,
              y: edge,
            ).destination(size, frame);
            expect(rect.left, lessThanOrEqualTo(0.001));
            expect(rect.top, lessThanOrEqualTo(0.001));
            expect(rect.right, greaterThanOrEqualTo(899.999));
            expect(rect.bottom, greaterThanOrEqualTo(1399.999));
          }
        }
        final whole = const PhotoFraming(contain: true)
            .destination(size, frame);
        expect(whole.left, greaterThanOrEqualTo(-0.001));
        expect(whole.top, greaterThanOrEqualTo(-0.001));
        expect(whole.right, lessThanOrEqualTo(900.001));
        expect(whole.bottom, lessThanOrEqualTo(1400.001));
      }
    },
  );

  test(
    'saved crop and whole-photo pixels match the selected framing',
    () async {
      final original = await File(source).readAsBytes();
      final service = CreationService();
      var depthCalls = 0;
      messenger.setMockMethodCallHandler(pipeline, (call) async {
        expect(call.method, 'depth');
        depthCalls++;
        return {'backgroundPath': call.arguments['path']};
      });
      for (final framing in [
        const PhotoFraming(),
        const PhotoFraming(x: -1),
        const PhotoFraming(x: 1),
        const PhotoFraming(contain: true),
      ]) {
        final result = await service.prepareBackground(
          source,
          framing: framing,
        );
        final codec = await ui.instantiateImageCodec(
          await File(result.depth['backgroundPath'] as String).readAsBytes(),
        );
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(image.width, 900);
        expect(image.height, 1400);
        final pixels = (await image.toByteData())!;
        Color pixel(int x, int y) {
          final i = (y * image.width + x) * 4;
          return Color.fromARGB(
            pixels.getUint8(i + 3),
            pixels.getUint8(i),
            pixels.getUint8(i + 1),
            pixels.getUint8(i + 2),
          );
        }

        expect(
          pixel(450, 700).toARGB32(),
          (framing.x < 0
                  ? Colors.red
                  : framing.x > 0
                  ? Colors.blue
                  : Colors.green)
              .toARGB32(),
        );
        if (framing.contain) {
          expect(pixel(450, 10), PhotoFraming.matte);
          expect(pixel(20, 700).toARGB32(), Colors.red.toARGB32());
          expect(pixel(880, 700).toARGB32(), Colors.blue.toARGB32());
        } else {
          expect(pixel(450, 10), pixel(450, 700));
        }
        image.dispose();
      }
      expect(depthCalls, 4);
      expect(await File(source).readAsBytes(), original);
    },
  );

  testWidgets('drag changes the crop and whole-photo mode disables cropping', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.runAsync(() async {
      var framing = const PhotoFraming();
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: SizedBox(
                  width: 180,
                  child: PhotoFrame(
                    path: source,
                    framing: framing,
                    onChanged: (value) => setState(() => framing = value),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PhotoFrame)),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await gesture.up();
      await tester.pump();
      expect(framing.x, lessThan(0));
      update(() => framing = const PhotoFraming(contain: true));
      await tester.pump();
      await tester.drag(find.byType(PhotoFrame), const Offset(-80, 0));
      expect(framing.x, 0);
      expect(framing.contain, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
