import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timo/features/memory/data/segmentation_service.dart';

// Device regression on the local photo reported by the user. No photo is uploaded.
// Run with --no-uninstall to preserve application data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'photographic model preserves raised fingertips on the reported photo',
    (tester) async {
      final root = await getApplicationDocumentsDirectory();
      final photo = '${root.path}/photos/1789021528476274.jpg';
      expect(
        await File(photo).exists(),
        true,
        reason: 'This regression uses the existing local user photo',
      );
      final started = DateTime.now();
      final result = await SegmentationService().removeBackground(photo);
      expect(
        result['engine'],
        'modnet',
        reason: 'Do not silently pass with the old model',
      );
      final codec = await ui.instantiateImageCodec(
        await File(result['path'] as String).readAsBytes(),
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final pixels = (await image.toByteData())!;
      final crop = result['crop'] as Map;
      int alpha(int x, int y) {
        final u = (x / 580 - (crop['left'] as num)) / (crop['width'] as num);
        final v = (y / 832 - (crop['top'] as num)) / (crop['height'] as num);
        if (u < 0 || u >= 1 || v < 0 || v >= 1) return 0;
        return pixels.getUint8(
          ((v * image.height).floor() * image.width +
                      (u * image.width).floor()) *
                  4 +
              3,
        );
      }

      // Foreground locations inside each of the four raised fingers and thumb.
      for (final p in [
        const ui.Offset(181, 155),
        const ui.Offset(193, 140),
        const ui.Offset(204, 136),
        const ui.Offset(217, 142),
        const ui.Offset(233, 166),
      ]) {
        expect(
          alpha(p.dx.toInt(), p.dy.toInt()),
          greaterThan(160),
          reason: 'finger at $p',
        );
      }
      expect(alpha(160, 180), lessThan(25));
      expect(alpha(400, 100), lessThan(25));
      expect(alpha(100, 500), lessThan(25));
      final copy = File('${root.path}/modnet_device_result.png');
      await File(result['path'] as String).copy(copy.path);
      image.dispose();
      // Runtime only; omit image paths from logs.
      // ignore: avoid_print
      print(
        'MODNet device total ms=${DateTime.now().difference(started).inMilliseconds}',
      );
    },
  );
}
