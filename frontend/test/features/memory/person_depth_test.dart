import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/depth_service.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';
import 'package:timo/features/memory/widgets/ui/person_depth_options.dart';
import 'package:timo/features/memory/data/creation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('timo/image_pipeline');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // Chest-level upper-body photo: shoulders at 0.55, no hips, face 0.3 tall.
  const upperBody = {
    'cropType': 'UPPER_BODY',
    'shoulderCenter': {'x': 0.5, 'y': 0.55},
    'faceHeight': 0.3,
    'width': 800,
    'height': 1000,
  };
  // Full body: shoulders at 0.2, hips at 0.45, hands hanging to 0.5.
  const fullBody = {
    'cropType': 'FULL_BODY',
    'shoulderCenter': {'x': 0.5, 'y': 0.2},
    'hipCenter': {'x': 0.5, 'y': 0.45},
    'torsoLength': 0.25,
    'handBottom': 0.5,
    'width': 600,
    'height': 1600,
  };
  // Same point on the full body's own shoulder-to-hip axis as where the
  // upper-body photo ends: 0.2 + (0.45 / (0.3 × 7.5 / 3.3)) × 0.25.
  final matchedBottom = 0.2 + (0.45 / (0.3 * 7.5 / 3.3)) * 0.25;

  test(
    'two people: the higher-ending cutout dictates where the other is cut',
    () {
      expect(
        CreationService.matchedCutoff(reference: upperBody, target: fullBody),
        closeTo(matchedBottom, 0.00001),
      );
      // The upper-body photo is never extended or cut to match a full body.
      expect(
        CreationService.matchedCutoff(reference: fullBody, target: upperBody),
        isNull,
      );
      // Two full bodies stay whole.
      expect(
        CreationService.matchedCutoff(reference: fullBody, target: fullBody),
        isNull,
      );
      // Without shoulders there is no skeleton to align to.
      expect(
        CreationService.matchedCutoff(
          reference: const {'cropType': 'UNKNOWN'},
          target: fullBody,
        ),
        isNull,
      );
      // A cut that would fall almost at the bottom is a no-op.
      expect(
        CreationService.matchedCutoff(
          reference: const {
            'shoulderCenter': {'y': 0.1},
            'torsoLength': 0.4,
          },
          target: const {
            'shoulderCenter': {'y': 0.2},
            'torsoLength': 0.36,
          },
        ),
        isNull,
      );
    },
  );

  test('matched cut leaves room for fingertips just below the line', () {
    final hands = Map<String, dynamic>.from(fullBody)
      ..['handBottom'] = matchedBottom + 0.03;
    expect(
      CreationService.matchedCutoff(reference: upperBody, target: hands),
      closeTo(matchedBottom + 0.03 + 0.045, 0.00001),
    );
    // Torso length falls back to face height, then shoulder width.
    expect(
      CreationService.torsoLength(const {
        'shoulderWidth': 0.5,
        'width': 800,
        'height': 1000,
      }),
      closeTo(0.5 * 0.8 * 4.0 / 3.3, 0.00001),
    );
  });

  test('a single person keeps the whole cutout and is only cropped next to an '
      'upper-body partner, then restored when alone again', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      switch (call.method) {
        case 'segment':
          return call.arguments['path'] == 'original.jpg'
              ? {
                  'path': 'full.png',
                  'crop': {
                    'left': 0.2,
                    'top': 0.1,
                    'width': 0.6,
                    'height': 0.8,
                  },
                }
              : {
                  'path': 'partner.png',
                  'crop': {
                    'left': 0.0,
                    'top': 0.0,
                    'width': 1.0,
                    'height': 1.0,
                  },
                };
        case 'analyzePerson':
          return switch (call.arguments['path']) {
            'full.png' => Map<String, dynamic>.from(fullBody),
            'partner.png' => Map<String, dynamic>.from(upperBody),
            _ => {'cropType': 'UPPER_BODY'},
          };
        case 'cropUpperBody':
          expect(call.arguments['path'], 'full.png');
          expect(call.arguments['bottom'], closeTo(matchedBottom, 0.00001));
          return {
            'path': 'upper.png',
            'crop': {'left': 0.1, 'top': 0.0, 'width': 0.8, 'height': 0.5},
          };
        case 'personDepth':
          if (call.arguments['cutout'] == 'upper.png') {
            expect(call.arguments['source'], 'original.jpg');
            final crop = call.arguments['crop'] as Map;
            expect(crop['left'], closeTo(0.26, 0.00001));
            expect(crop['top'], closeTo(0.1, 0.00001));
            expect(crop['width'], closeTo(0.48, 0.00001));
            expect(crop['height'], closeTo(0.4, 0.00001));
            return {'available': true, 'depthMapPath': 'upper-depth.png'};
          }
          return {'available': true, 'depthMapPath': 'depth.png'};
      }
      fail('Unexpected method ${call.method}');
    });
    final service = CreationService();
    final person = await service.segmentAndAnalyze('original.jpg');
    expect(person['upperBodyCropped'], false);
    expect(person['path'], 'full.png');
    expect(person['originalCropType'], 'FULL_BODY');
    expect(person['depthStrength'], 'weak');
    expect(methods, ['segment', 'analyzePerson', 'personDepth']);

    // Alone: nothing to match against.
    expect(await service.harmonizeCrops([person]), isEmpty);
    expect(person['path'], 'full.png');

    final partner = await service.segmentAndAnalyze('partner.jpg');
    methods.clear();
    expect(await service.harmonizeCrops([person, partner]), [0]);
    expect(person['upperBodyCropped'], true);
    expect(person['path'], 'upper.png');
    expect(person['personDepthPath'], 'upper-depth.png');
    expect((person['sourceCrop'] as Map)['left'], closeTo(0.26, 0.00001));
    expect(partner['upperBodyCropped'], false);
    expect(partner['path'], 'partner.png');
    expect(methods, ['cropUpperBody', 'analyzePerson', 'personDepth']);

    // Partner removed: the full cutout and its depth come back untouched.
    methods.clear();
    expect(await service.harmonizeCrops([person]), [0]);
    expect(person['upperBodyCropped'], false);
    expect(person['path'], 'full.png');
    expect(person['personDepthPath'], 'depth.png');
    expect((person['sourceCrop'] as Map)['left'], closeTo(0.2, 0.00001));
    expect(methods, isEmpty);
  });

  test('person inference uses original and exact segmentation crop without extending', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'available': true, 'depthMapPath': 'person-depth.png'};
    });
    final crop = {'left': 0.15, 'top': 0.1, 'width': 0.6, 'height': 0.8};
    expect(
      await DepthService().analyzePerson(
        source: 'original.jpg',
        cutout: 'person.png',
        crop: crop,
      ),
      'person-depth.png',
    );
    expect(calls.single.method, 'personDepth');
    expect(calls.single.arguments, {
      'source': 'original.jpg',
      'cutout': 'person.png',
      'crop': crop,
    });
  });

  test(
    'inference failure returns fixed-photo fallback instead of invented depth',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'FAILED'),
      );
      expect(
        await DepthService().analyzePerson(
          source: 'original.jpg',
          cutout: 'person.png',
          crop: {},
        ),
        isNull,
      );
      expect(PersonDepthStrength.fromName(null), PersonDepthStrength.weak);
    },
  );

  testWidgets(
    'strength controls default weak and change only the selected value',
    (tester) async {
      var value = PersonDepthStrength.weak;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PersonDepthOptions(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('person-depth-weak')))
            .selected,
        true,
      );
      await tester.tap(find.byKey(const ValueKey('person-depth-off')));
      await tester.pump();
      expect(value, PersonDepthStrength.off);
      await tester.tap(find.byKey(const ValueKey('person-depth-strong')));
      await tester.pump();
      expect(value, PersonDepthStrength.strong);
    },
  );

  test(
    'depth shader preserves alpha and rest pose while weak and strong differ',
    () async {
      const size = 128;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.clipPath(Path()..addOval(const Rect.fromLTWH(8, 8, 112, 112)));
      for (var x = 0; x < size; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), 0, 1, 128),
          Paint()..color = x % 8 < 4 ? Colors.red : Colors.blue,
        );
      }
      final picture = recorder.endRecording();
      final photo = await picture.toImage(size, size);
      picture.dispose();
      final depthRecorder = ui.PictureRecorder();
      Canvas(depthRecorder).drawRect(
        const Rect.fromLTWH(0, 0, 128, 128),
        Paint()..color = Colors.white,
      );
      final depthPicture = depthRecorder.endRecording();
      final depth = await depthPicture.toImage(size, size);
      depthPicture.dispose();
      final shader = (await ui.FragmentProgram.fromAsset(
        'shaders/person_depth.frag',
      )).fragmentShader();
      Future<ByteData> render(double tilt, PersonDepthStrength strength) async {
        shader
          ..setFloat(0, 128)
          ..setFloat(1, 128)
          ..setFloat(2, tilt)
          ..setFloat(3, 0)
          ..setFloat(4, strength.displacement)
          ..setImageSampler(0, photo)
          ..setImageSampler(1, depth);
        final r = ui.PictureRecorder();
        Canvas(r).drawRect(
          const Rect.fromLTWH(0, 0, 128, 128),
          Paint()..shader = shader,
        );
        final p = r.endRecording();
        final image = await p.toImage(size, size);
        p.dispose();
        final data = (await image.toByteData())!;
        image.dispose();
        return data;
      }

      final original = (await photo.toByteData())!;
      final rest = await render(0, PersonDepthStrength.weak);
      final off = await render(1, PersonDepthStrength.off);
      final weak = await render(1, PersonDepthStrength.weak);
      final strong = await render(1, PersonDepthStrength.strong);
      var weakDifference = 0, strongDifference = 0;
      for (var i = 0; i < size * size * 4; i += 4) {
        expect(weak.getUint8(i + 3), original.getUint8(i + 3));
        expect(strong.getUint8(i + 3), original.getUint8(i + 3));
        for (var c = 0; c < 3; c++) {
          expect(rest.getUint8(i + c), closeTo(original.getUint8(i + c), 1));
          expect(off.getUint8(i + c), closeTo(original.getUint8(i + c), 1));
          weakDifference += (weak.getUint8(i + c) - original.getUint8(i + c))
              .abs();
          strongDifference +=
              (strong.getUint8(i + c) - original.getUint8(i + c)).abs();
        }
      }
      expect(weakDifference, greaterThan(100));
      expect(strongDifference, greaterThan(weakDifference));
      shader.dispose();
      photo.dispose();
      depth.dispose();
    },
  );
}
