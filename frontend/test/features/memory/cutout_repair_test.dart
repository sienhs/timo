import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/widgets/creator/cutout_repair_editor.dart';

Future<ui.Image> solid(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('repair controls fit a phone and brush edits can be undone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Directory folder;
    await tester.runAsync(() async {
      folder = await Directory.systemTemp.createTemp('timo_repair_test_');
      final image = await solid(100, 160, Colors.orange);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File('${folder.path}/source.png')
          .writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
    });
    const channel = MethodChannel('timo/image_pipeline');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => '${folder.path}/source.png',
    );
    addTearDown(() async {
      messenger.setMockMethodCallHandler(channel, null);
      await folder.delete(recursive: true);
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: CutoutRepairEditor(
            person: {
              'sourcePath': '${folder.path}/source.png',
              'path': '${folder.path}/source.png',
              'sourceCrop': {
                'left': 0.2,
                'top': 0.1,
                'width': 0.6,
                'height': 0.7,
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.text('누끼 보정'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '적용'))
          .onPressed,
      isNull,
    );
    await tester.tapAt(tester.getCenter(find.byType(InteractiveViewer)));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '적용'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('되돌리기'));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '적용'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('확대/이동'));
    await tester.pump();
    await tester.drag(find.byType(InteractiveViewer), const Offset(15, 15));
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '적용'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'restore uses original pixels, erase removes alpha, undo restores mask',
    () async {
      final source = await solid(100, 100, const Color(0xFFFF4400));
      final cutout = await solid(20, 20, Colors.blue);
      final strokes = [
        RepairStroke(true, 0.08, [
          const Offset(0.7, 0.5),
          const Offset(0.8, 0.5),
        ]),
        RepairStroke(false, 0.06, [const Offset(0.5, 0.5)]),
      ];
      Future<ByteData> render() async {
        final recorder = ui.PictureRecorder();
        paintRepairedCutout(
          Canvas(recorder),
          const Size(100, 100),
          source,
          cutout,
          const Rect.fromLTWH(0.4, 0.4, 0.2, 0.2),
          strokes,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(100, 100);
        picture.dispose();
        try {
          return (await image.toByteData())!;
        } finally {
          image.dispose();
        }
      }

      int pixel(ByteData data, int x, int y) =>
          data.getUint32((y * 100 + x) * 4);
      final painted = await render();
      expect(
        pixel(painted, 75, 50),
        0xFF4400FF,
      ); // Real source colour restored.
      expect(pixel(painted, 50, 50), 0); // Erased within the existing person.
      expect(pixel(painted, 10, 10), 0); // Background remains transparent.
      expect(pixel(painted, 43, 43), 0xFF4400FF); // Original mask preserved.
      strokes.removeLast();
      expect(pixel(await render(), 50, 50), 0xFF4400FF);
      strokes.clear();
      expect(pixel(await render(), 75, 50), 0);
      source.dispose();
      cutout.dispose();
    },
  );

  test(
    'repair re-aligns bounds and depth without another automatic waist crop',
    () async {
      const channel = MethodChannel('timo/image_pipeline');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'cropUpperBody':
            expect(call.arguments['bottom'], 1.0);
            return {
              'path': 'repaired.png',
              'crop': {'left': 0.1, 'top': 0.1, 'width': 0.8, 'height': 0.7},
            };
          case 'analyzePerson':
            return {'cropType': 'HALF_BODY'};
          case 'personDepth':
            expect(call.arguments['source'], 'original.jpg');
            expect(call.arguments['cutout'], 'repaired.png');
            expect(call.arguments['crop']['width'], 0.8);
            return {'available': true, 'depthMapPath': 'repaired-depth.png'};
        }
        fail('Unexpected call ${call.method}');
      });
      final person = {
        'sourcePath': 'original.jpg',
        'sourceCrop': {'left': 0.2, 'top': 0.1, 'width': 0.6, 'height': 0.5},
        'placement': {'left': 0.3, 'top': 0.2, 'width': 0.3, 'height': 0.4},
        'initialPlacement': {
          'left': 0.3,
          'top': 0.2,
          'width': 0.3,
          'height': 0.4,
        },
        'depthStrength': 'weak',
        'order': 2,
      };
      final repaired = await CreationService().repairPerson(
        person,
        'full-repair.png',
      );
      final placement = repaired['placement'] as Map;
      expect(placement['left'], closeTo(0.25, 0.00001));
      expect(placement['top'], closeTo(0.2, 0.00001));
      expect(placement['width'], closeTo(0.4, 0.00001));
      expect(placement['height'], closeTo(0.56, 0.00001));
      expect(repaired['depthStrength'], 'weak');
      expect(repaired['order'], 2);
      expect(calls, ['cropUpperBody', 'analyzePerson', 'personDepth']);
    },
  );
}
