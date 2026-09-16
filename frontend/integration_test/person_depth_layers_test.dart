import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/widgets/viewer/person_depth_photo.dart';
import 'package:timo/features/memory/effects/shader_cache.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';
import 'package:timo/features/memory/widgets/ui/local_image.dart';

Future<ui.Image> decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real pose and depth split into body-part layers that render on Android',
    (tester) async {
      final service = CreationService();
      final source = await service.copyPhotoToPrivateStorage(
        'assets/demo/pose_test.jpg',
        asset: true,
      );
      final started = DateTime.now();
      final person = await service.segmentAndAnalyze(source);
      final elapsed = DateTime.now().difference(started);
      expect(person['personDepthPath'], isNotNull, reason: 'real inference');
      final analysis = person['analysis'] as Map;
      expect(
        analysis['landmarks'],
        isA<List>().having((l) => l.length, 'landmarks', 33),
        reason: 'native analyze must hand the raw pose to Dart',
      );
      final parts = [
        for (final p in person['parts'] as List)
          PersonPart.fromJson(Map<String, dynamic>.from(p as Map)),
      ];
      expect(
        parts.length,
        greaterThanOrEqualTo(2),
        reason: 'a full-body photo must split into layers',
      );
      expect(person['layeredDepth'], true);
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i].depth, greaterThanOrEqualTo(parts[i - 1].depth));
      }
      final partMap = await decode(person['partMapPath'] as String);
      expect(
        math.max(partMap.width, partMap.height),
        lessThanOrEqualTo(PersonLayeringConstants.workingLongSide),
      );
      final cutout = await decode(person['path'] as String);
      expect(
        partMap.width / partMap.height,
        closeTo(cutout.width / cutout.height, 0.02),
      );
      final mapBytes = (await partMap.toByteData())!;
      for (var i = 3; i < mapBytes.lengthInBytes; i += 4) {
        expect(
          mapBytes.getUint8(i),
          255,
          reason: 'weights must not premultiply',
        );
      }
      partMap.dispose();
      cutout.dispose();
      // The split alone, on files that already exist.
      final splitStarted = DateTime.now();
      final again = await service.layering.build(
        cutoutPath: person['path'] as String,
        depthMapPath: person['personDepthPath'] as String,
        analysis: Map<String, dynamic>.from(analysis),
      );
      final splitMs = DateTime.now().difference(splitStarted).inMilliseconds;
      expect(again, isNotNull);
      expect(again!.layers.length, parts.length);
      debugPrint(
        'Person layers: ${[for (final p in parts) '${p.label} depth=${p.depth.toStringAsFixed(2)} share=${p.share.toStringAsFixed(2)}'].join(', ')}; pipeline ms=${elapsed.inMilliseconds}; split ms=$splitMs',
      );

      PersonDepthLayer layerFor(bool layered) => PersonDepthLayer.fromJson({
        'path': person['path'],
        'depthMapPath': person['personDepthPath'],
        'partMapPath': person['partMapPath'],
        'parts': person['parts'],
        'layered': layered,
        'strength': PersonDepthStrength.strong.name,
        'placement': {'left': 0.2, 'top': 0.2, 'width': 0.4, 'height': 0.6},
      });
      final tilt = ValueNotifier(const Offset(12, -6));
      const capture = ValueKey('person-layers-capture');
      Future<void> show(PersonDepthLayer layer) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: capture,
                  child: SizedBox(
                    width: 240,
                    height: 360,
                    child: PersonDepthPhoto(layer: layer, tilt: tilt),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.descendant(
            of: find.byType(PersonDepthPhoto),
            matching: find.byType(LocalImage),
          ),
          findsNothing,
          reason: 'Android must use the real shader, not the static fallback',
        );
      }

      Future<ByteData> screenshot(String name) async {
        final image = await tester
            .renderObject<RenderRepaintBoundary>(find.byKey(capture))
            .toImage();
        final pixels = (await image.toByteData())!;
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${File(source).parent.path}/$name.png')
            .writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
        return pixels;
      }

      await show(layerFor(true));
      expect(
        tester.widget<ShaderBuilder>(find.byType(ShaderBuilder)).asset,
        PersonDepthPhoto.layeredShader,
      );
      final layered = await screenshot('person_layers_on');
      await show(layerFor(false));
      expect(
        tester.widget<ShaderBuilder>(find.byType(ShaderBuilder)).asset,
        PersonDepthPhoto.singleShader,
      );
      final single = await screenshot('person_layers_off');
      tilt.value = Offset.zero;
      await tester.pump(const Duration(milliseconds: 300));
      final rest = await screenshot('person_layers_rest');

      var silhouetteChanges = 0, maxAlphaError = 0, colorChanges = 0;
      for (var i = 0; i < layered.lengthInBytes; i += 4) {
        final a = layered.getUint8(i + 3), b = single.getUint8(i + 3);
        maxAlphaError = math.max(maxAlphaError, (a - b).abs());
        if ((a > 127) != (b > 127)) silhouetteChanges++;
        if ((layered.getUint8(i) - single.getUint8(i)).abs() > 8) {
          colorChanges++;
        }
      }
      debugPrint(
        'Person layers capture: ${File(source).parent.path}; silhouette=$silhouetteChanges; maxAlpha=$maxAlphaError; colorChanges=$colorChanges; restAlphaBytes=${rest.lengthInBytes}',
      );
      // Same outline as the single-map shader; visibly different interior.
      expect(silhouetteChanges, 0);
      expect(maxAlphaError, lessThanOrEqualTo(8));
      expect(colorChanges, greaterThan(100));
      await tester.pumpWidget(const SizedBox());
      tilt.dispose();
      binding.reportData = {
        'layers': [for (final p in parts) p.toJson()],
        'analysisMs': elapsed.inMilliseconds,
        'splitMs': splitMs,
        'silhouetteChanges': silhouetteChanges,
        'maxAlphaReadbackDifference': maxAlphaError,
        'layeredVsSingleChangedPixels': colorChanges,
        'imageFolder': File(source).parent.path,
      };
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
