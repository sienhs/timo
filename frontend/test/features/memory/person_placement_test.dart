import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/data/person_placement.dart';
import 'package:timo/features/memory/data/composition_service.dart';
import 'package:timo/features/memory/widgets/creator/person_placement_editor.dart';
import 'package:timo/features/memory/models/photo_framing.dart';

Future<void> solid(String path, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 100, 200), Paint()..color = color);
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 200);
  picture.dispose();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  image.dispose();
}

Map<String, dynamic> person(String path, Rect rect, int order) => {
  'path': path,
  'placement': PersonPlacement(rect).toJson(),
  'initialPlacement': PersonPlacement(rect).toJson(),
  'order': order,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('timo_placement_');
    await solid('${folder.path}/red.png', Colors.red);
    await solid('${folder.path}/blue.png', Colors.blue);
    messenger.setMockMethodCallHandler(paths, (_) async => folder.path);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(paths, null);
    await folder.delete(recursive: true);
  });

  test('all corners preserve aspect, opposite anchor and canvas bounds', () {
    const start = PersonPlacement(Rect.fromLTWH(0.2, 0.2, 0.3, 0.5));
    for (final corner in [
      const Offset(-1, -1),
      const Offset(1, -1),
      const Offset(-1, 1),
      const Offset(1, 1),
    ]) {
      for (final delta in [
        const Offset(40, 50),
        const Offset(-5000, -5000),
        const Offset(5000, 5000),
      ]) {
        final next = start
            .resize(delta, corner, const Size(320, 320 * 14 / 9))
            .rect;
        expect(next.width / next.height, closeTo(0.6, 0.00001));
        expect(next.left, greaterThanOrEqualTo(-0.00001));
        expect(next.top, greaterThanOrEqualTo(-0.00001));
        expect(next.right, lessThanOrEqualTo(1.00001));
        expect(next.bottom, lessThanOrEqualTo(1.00001));
        expect(
          corner.dx > 0 ? next.left : next.right,
          closeTo(corner.dx > 0 ? start.rect.left : start.rect.right, 0.00001),
        );
        expect(
          corner.dy > 0 ? next.top : next.bottom,
          closeTo(corner.dy > 0 ? start.rect.top : start.rect.bottom, 0.00001),
        );
      }
    }
  });

  test(
    'saved pixels retain independent positions, sizes and front order',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = CompositionService();
      final people = [
        person(
          '${folder.path}/red.png',
          const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4),
          0,
        ),
        person(
          '${folder.path}/blue.png',
          const Rect.fromLTWH(0.3, 0.4, 0.25, 0.4),
          1,
        ),
      ];
      Future<List<int>> pixelsAt(List<Offset> points) async {
        final path = await service.compose(people);
        final codec = await ui.instantiateImageCodec(
          await File(path).readAsBytes(),
        );
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        expect((image.width, image.height), (900, 1400));
        final bytes = (await image.toByteData())!;
        final result = points.map((p) {
          final i = (((p.dy * 1400).floor() * 900) + (p.dx * 900).floor()) * 4;
          return Color.fromARGB(
            bytes.getUint8(i + 3),
            bytes.getUint8(i),
            bytes.getUint8(i + 1),
            bytes.getUint8(i + 2),
          ).toARGB32();
        }).toList();
        image.dispose();
        return result;
      }

      final red = Colors.red.toARGB32(), blue = Colors.blue.toARGB32();
      const points = [
        Offset(0.2, 0.3),
        Offset(0.35, 0.5),
        Offset(0.5, 0.7),
        Offset(0.8, 0.8),
      ];
      expect(await pixelsAt(points), [red, blue, blue, 0]);
      people[0]['order'] = 2;
      expect(await pixelsAt(points), [red, red, blue, 0]);
      final other = Map.of(people[1]['placement'] as Map);
      people[0]['placement'] = PersonPlacement.fromPerson(people[0])
          .scaleBy(0.5)
          .toJson();
      expect(
        await pixelsAt(const [
          Offset(0.11, 0.21),
          Offset(0.25, 0.4),
          Offset(0.5, 0.7),
        ]),
        [0, red, blue],
      );
      expect(people[1]['placement'], other);
    },
  );

  testWidgets('selection isolates drag and resize, deselection locks editing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      final font = File('C:/Windows/Fonts/malgun.ttf');
      if (await font.exists()) {
        final loader = FontLoader('TestKorean')
          ..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          );
        await loader.load();
      }
      final people = [
        person(
          File('assets/demo/person_a.png').absolute.path,
          const Rect.fromLTWH(0.16, 0.22, 0.34, 0.55),
          0,
        ),
        person(
          File('assets/demo/person_b.png').absolute.path,
          const Rect.fromLTWH(0.46, 0.25, 0.34, 0.55),
          1,
        ),
      ];
      const capture = ValueKey('editor-capture');
      await tester.pumpWidget(
        MaterialApp(
          theme: timoTheme().copyWith(
            textTheme: timoTheme().textTheme.apply(fontFamily: 'TestKorean'),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: StatefulBuilder(
                  builder: (context, setState) => RepaintBoundary(
                    key: capture,
                    child: PersonPlacementEditor(
                      background: File('assets/demo/stage_blue.png')
                          .absolute
                          .path,
                      framing: const PhotoFraming(),
                      people: people,
                      onChanged: (i, changes) =>
                          setState(() => people[i].addAll(changes)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
      final first = Map.of(people[0]['placement'] as Map);
      await tester.tap(find.byKey(const ValueKey('select-person-1')));
      await tester.pump();
      final before = PersonPlacement.fromPerson(people[1]).rect;
      await tester.drag(
        find.byKey(const ValueKey('move-person-1')),
        const Offset(-25, -15),
      );
      await tester.pump();
      expect(
        PersonPlacement.fromPerson(people[1]).rect.left,
        lessThan(before.left),
      );
      expect(people[0]['placement'], first);
      final moved = PersonPlacement.fromPerson(people[1]).rect;
      await tester.drag(
        find.byKey(const ValueKey('resize-person-1-3')),
        const Offset(25, 30),
      );
      await tester.pump();
      final resized = PersonPlacement.fromPerson(people[1]).rect;
      expect(resized.width, greaterThan(moved.width));
      expect(
        resized.width / resized.height,
        closeTo(moved.width / moved.height, 0.00001),
      );
      expect(people[0]['placement'], first);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      final screenshot = await boundary.toImage(pixelRatio: 2);
      final png = (await screenshot.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      final output = await Directory('verification/person_placement')
          .create(recursive: true);
      await File('${output.path}/editor.png')
          .writeAsBytes(png.buffer.asUint8List());
      screenshot.dispose();
      await tester.tap(find.text('선택 해제'));
      await tester.pump();
      expect(find.byKey(const ValueKey('move-person-1')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('placement-person-1')),
        const Offset(30, 0),
      );
      expect(PersonPlacement.fromPerson(people[1]).rect, resized);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
