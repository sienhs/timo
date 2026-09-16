import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import 'outpaint_canvas.dart';
import 'outpaint_service.dart';

/// Outcome of trying to fill a photo to the card aspect with AI.
enum BackgroundExtensionOutcome {
  /// Photo already matched, or AI is not configured: nothing was generated.
  skipped,

  /// A generated, full-aspect image was written to [BackgroundExtension.path].
  generated,

  /// AI was available but failed; caller should fall back.
  failed,
}

class BackgroundExtension {
  const BackgroundExtension(this.outcome, {this.path, this.error});
  final BackgroundExtensionOutcome outcome;
  final String? path;
  final Object? error;
}

/// Runs generative outpainting once per photo and stores the result in the
/// app's private storage so it is never requested twice.
class BackgroundExtensionService {
  BackgroundExtensionService(this.outpaint);
  final OutpaintService outpaint;

  bool get available => outpaint.available;

  Future<BackgroundExtension> extendToAspect(
    String path,
    double targetAspect,
  ) async {
    if (!outpaint.available) {
      return const BackgroundExtension(BackgroundExtensionOutcome.skipped);
    }
    try {
      final bytes = await File(path).readAsBytes();
      final size = await _sizeOf(bytes);
      final plan = OutpaintPlan.forAspect(
        width: size.width,
        height: size.height,
        targetAspect: targetAspect,
      );
      if (plan.isEmpty) {
        return const BackgroundExtension(BackgroundExtensionOutcome.skipped);
      }
      final generated = await outpaint.outpaint(
        image: bytes,
        plan: plan,
        prompt: BackgroundExtensionConstants.prompt,
      );
      // Never let the model touch the photo itself: paste the original back.
      final composed = await OutpaintCanvas.compositeOriginal(
        generated,
        bytes,
        plan,
      );
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory('${root.path}/photos');
      await folder.create(recursive: true);
      final target = File(
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}_ai.png',
      );
      await target.writeAsBytes(composed);
      return BackgroundExtension(
        BackgroundExtensionOutcome.generated,
        path: target.path,
      );
    } catch (error) {
      return BackgroundExtension(
        BackgroundExtensionOutcome.failed,
        error: error,
      );
    }
  }

  static Future<({int width, int height})> _sizeOf(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = (width: descriptor.width, height: descriptor.height);
      descriptor.dispose();
      return size;
    } finally {
      buffer.dispose();
    }
  }
}
