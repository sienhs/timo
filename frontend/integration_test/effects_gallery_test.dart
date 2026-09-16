import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/widgets/viewer/effect_layer.dart';
import 'package:timo/features/memory/effects/effect_quality.dart';
import 'package:timo/features/memory/models/ticket_effect.dart';

/// Renders every stage effect over a dark stage at high quality and saves a
/// screenshot per effect (`effect_NAME.png` in the app documents folder).
/// Visual regression aid: pull the files with `adb exec-out run-as`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('every GPU effect renders on device without exceptions', (
    tester,
  ) async {
    EffectQualityController.instance.lock(EffectQuality.high);
    final folder = await getApplicationDocumentsDirectory();
    var converted = false;
    for (final effect in TicketEffect.values) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: timoTheme(),
          home: Scaffold(
            body: Center(
              child: AspectRatio(
                aspectRatio: 9 / 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF101A33), Color(0xFF05070D)],
                          ),
                        ),
                      ),
                      EffectLayer(effect: effect),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // Let shaders compile and the clock advance to a lively frame.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      await tester.pump();
      final bytes = await binding.takeScreenshot('effect_${effect.name}');
      await File('${folder.path}/effect_${effect.name}.png')
          .writeAsBytes(bytes);
      expect(tester.takeException(), isNull, reason: effect.label);
    }
    EffectQualityController.instance.unlock();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
