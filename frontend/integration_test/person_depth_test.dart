import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/widgets/viewer/person_depth_photo.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';
import 'package:timo/features/memory/widgets/ui/local_image.dart';
import 'package:timo/features/memory/widgets/ui/person_depth_options.dart';

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
  testWidgets('real person depth aligns with cutout and renders on Android', (
    tester,
  ) async {
    final service = CreationService();
    final source = await service.copyPhotoToPrivateStorage(
      'assets/demo/pose_test.jpg',
      asset: true,
    );
    final person = await service.segmentAndAnalyze(source);
    expect(
      person['personDepthPath'],
      isNotNull,
      reason: 'real inference must succeed',
    );
    expect(person['depthStrength'], 'weak');
    expect(person['upperBodyCropped'], false);
    expect(person['originalCropType'], 'FULL_BODY');
    expect(person['sourcePath'], source);
    final cutout = await decode(person['path'] as String);
    final depth = await decode(person['personDepthPath'] as String);
    expect((depth.width, depth.height), (cutout.width, cutout.height));
    final map = (await depth.toByteData())!;
    final mask = (await cutout.toByteData())!;
    final foregroundValues = <int>{};
    var outside = 0;
    for (var i = 0; i < depth.width * depth.height; i += 7) {
      if (mask.getUint8(i * 4 + 3) > 200) {
        foregroundValues.add(map.getUint8(i * 4));
      }
      if (mask.getUint8(i * 4 + 3) <= 12) {
        expect(map.getUint8(i * 4), 128);
        outside++;
      }
    }
    expect(foregroundValues.length, greaterThan(30));
    expect(outside, greaterThan(100));
    final width = depth.width, height = depth.height;
    cutout.dispose();
    depth.dispose();
    var layer = PersonDepthLayer(
      path: person['path'] as String,
      depthMapPath: person['personDepthPath'] as String,
      placement: const Rect.fromLTWH(0.2, 0.2, 0.4, 0.6),
    );
    final tilt = ValueNotifier(const Offset(12, -6));
    const capture = ValueKey('person-depth-capture');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 320,
                height: 550,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      key: capture,
                      child: SizedBox(
                        width: 240,
                        height: 360,
                        child: PersonDepthPhoto(layer: layer, tilt: tilt),
                      ),
                    ),
                    PersonDepthOptions(
                      value: layer.strength,
                      onChanged: (value) =>
                          setState(() => layer = layer.withStrength(value)),
                    ),
                  ],
                ),
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
      reason: 'Android must use the real depth shader, not the static fallback',
    );
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

    final weak = await screenshot('person_depth_weak');
    await tester.tap(find.byKey(const ValueKey('person-depth-strong')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(layer.strength, PersonDepthStrength.strong);
    final strong = await screenshot('person_depth_strong');
    final alphaChanges = [
      for (var i = 3; i < weak.lengthInBytes; i += 4)
        if (weak.getUint8(i) != strong.getUint8(i)) i,
    ].length;
    var maxAlphaError = 0, silhouetteChanges = 0;
    for (var i = 3; i < weak.lengthInBytes; i += 4) {
      final error = (weak.getUint8(i) - strong.getUint8(i)).abs();
      if (error > maxAlphaError) maxAlphaError = error;
      if ((weak.getUint8(i) > 127) != (strong.getUint8(i) > 127)) {
        silhouetteChanges++;
      }
    }
    debugPrint(
      'Person depth capture: ${File(source).parent.path}; alpha differences=$alphaChanges; max=$maxAlphaError; silhouette=$silhouetteChanges',
    );
    var changes = 0;
    // Device readback can differ slightly at soft alpha pixels. Require an
    // unchanged 50% contour and bound those differences to <1% of the image.
    expect(silhouetteChanges, 0);
    expect(maxAlphaError, lessThanOrEqualTo(8));
    expect(alphaChanges, lessThan(weak.lengthInBytes / 4 * 0.01));
    for (var i = 0; i < weak.lengthInBytes; i += 4) {
      if (weak.getUint8(i) != strong.getUint8(i)) changes++;
    }
    expect(changes, greaterThan(100));
    await tester.tap(find.byKey(const ValueKey('person-depth-off')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.descendant(
        of: find.byType(PersonDepthPhoto),
        matching: find.byType(LocalImage),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    tilt.dispose();
    binding.reportData = {
      'personDepth': 'real ONNX inference',
      'size': '$width x $height',
      'foregroundLevels': foregroundValues.length,
      'weakStrongChangedPixels': changes,
      'silhouetteChanges': silhouetteChanges,
      'maxAlphaReadbackDifference': maxAlphaError,
      'alphaChangedPixels': alphaChanges,
      'imageFolder': File(source).parent.path,
    };
  }, timeout: const Timeout(Duration(minutes: 4)));
}
