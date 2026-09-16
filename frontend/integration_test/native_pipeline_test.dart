import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/data/memory_concert_api.dart';
import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android segmentation, pose, safe two-person composition, ONNX depth and persistence',
    (tester) async {
      final service = CreationService();
      final source = await service.copyPhotoToPrivateStorage(
        'assets/demo/pose_test.jpg',
        asset: true,
      );
      final person = await service.segmentAndAnalyze(source);
      expect(person['segmented'], true);
      final analysis = person['analysis'] as Map;
      expect(analysis['poseAvailable'], true);
      expect(person['originalCropType'], 'FULL_BODY');
      expect(person['upperBodyCropped'], false, reason: 'alone stays whole');
      final source2 = await service.copyPhotoToPrivateStorage(
        'assets/demo/pose_upper.jpg',
        asset: true,
      );
      final person2 = await service.segmentAndAnalyze(source2);
      final a2 = person2['analysis'] as Map;
      expect(a2['cropType'], anyOf('UPPER_BODY', 'HALF_BODY'));
      expect(await service.harmonizeCrops([person, person2]), [0]);
      expect(person['upperBodyCropped'], true, reason: 'matched to partner');
      expect(person2['upperBodyCropped'], false);
      final bg = await service.copyPhotoToPrivateStorage(
        'assets/demo/stage_blue.png',
        asset: true,
      );
      final concert = (await MockMemoryConcertApi().getConcerts()).first;
      final ticket = await service.generateTicket(
        concert: concert,
        background: bg,
        people: [person, person2],
        effect: '꽃가루',
      );
      expect(ticket.depthLayers, hasLength(3));
      expect(ticket.demoDepth, false, reason: 'bundled Small model must infer');
      final depthCodec = await ui.instantiateImageCodec(
        await File(ticket.depthMapPath!).readAsBytes(),
      );
      final depthImage = (await depthCodec.getNextFrame()).image;
      expect((depthImage.width, depthImage.height), (518, 518));
      final depthBytes = (await depthImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var horizontalChanges = 0;
      for (var y = 0; y < 518; y += 7) {
        for (var x = 1; x < 518; x++) {
          if (depthBytes.getUint8((y * 518 + x) * 4) !=
              depthBytes.getUint8((y * 518 + x - 1) * 4)) {
            horizontalChanges++;
          }
        }
      }
      expect(
        horizontalChanges,
        greaterThan(100),
        reason: 'depth must follow image content, not a vertical demo ramp',
      );
      depthImage.dispose();
      depthCodec.dispose();
      expect(ticket.transition['firstFrameAnalyzed'], true);
      final codec = await ui.instantiateImageCodec(
        await File(ticket.personCompositePath!).readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      var left = 0, right = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
          if (x == 0 ||
              y == 0 ||
              x == image.width - 1 ||
              y == image.height - 1) {
            expect(alpha, 0, reason: 'outer canvas must stay transparent');
          }
          if (alpha > 128) {
            if (x < image.width / 2) {
              left++;
            } else {
              right++;
            }
          }
        }
      }
      expect(left, greaterThan(1000));
      expect(right, greaterThan(1000));
      image.dispose();
      codec.dispose();
      // Force both analysis fallbacks without pretending the models succeeded.
      final fallback = {
        ...person,
        'analysis': {
          'cropType': 'UNKNOWN',
          'poseAvailable': false,
          'faceAvailable': false,
        },
      };
      final fallbackPath = await service.composition.compose([
        fallback,
        {...fallback, 'dx': 0.2, 'scale': 1.5},
      ]);
      expect(await File(fallbackPath).exists(), true);
      await Hive.initFlutter();
      final box = await Hive.openBox<String>('native_test');
      await HiveTicketStore(box).save(ticket);
      await box.close();
      final reopened = await Hive.openBox<String>('native_test');
      expect(HiveTicketStore(reopened).readAll().first.toJson(), ticket.toJson());
      await reopened.close();
      binding.reportData = {
        'native': 'passed',
        'fullBody': analysis['cropType'],
        'croppedBody': a2['cropType'],
        'faceDetected': analysis['faceAvailable'],
        'depth': 'Depth Anything V2 Small real ONNX inference',
        'depthMapPath': ticket.depthMapPath,
        'backgroundPath': ticket.backgroundPath,
        'horizontalDepthChanges': horizontalChanges,
        'safeComposite': 'nonempty left/right; transparent outer boundary',
        'videoFirstFrame': 'analyzed',
      };
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
