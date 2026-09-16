import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/data/background_extension_service.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/outpaint_config.dart';

/// Real call to the configured outpainting provider (costs credits).
/// Run with:  flutter test integration_test/ai_outpaint_test.dart \
///              -d emulator-5554 --dart-define-from-file=.env
/// Skipped when no key is configured. Saves ai_background.png for review.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'landscape photo is outpainted by the configured AI',
    (tester) async {
      final service = CreationService();
      final source = await service.copyPhotoToPrivateStorage(
        'assets/demo/pose_test.jpg',
        asset: true,
      );
      // Same call the creator's "쓰기" button makes on the background step.
      final prepared = await service.extension.extendToAspect(
        source,
        ViewerConstants.cardAspect,
      );
      // Surface the provider's own message when it fails.
      expect(
        prepared.outcome,
        BackgroundExtensionOutcome.generated,
        reason: prepared.error?.toString(),
      );
      final folder = await getApplicationDocumentsDirectory();
      await File(prepared.path!).copy('${folder.path}/ai_background.png');
    },
    skip: !OutpaintConfig.hasKey,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
