import 'dart:typed_data';
import 'dart:ui' as ui;

import 'outpaint_service.dart';

/// Pixel helpers for outpainting: pad a photo onto a larger canvas and paste
/// the untouched original back over a generated result.
class OutpaintCanvas {
  static Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  static Future<Uint8List> encodePng(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  /// Photo centred on a canvas enlarged by [plan]; the new bands are
  /// [fill] (transparent by default, which image-edit APIs treat as the
  /// region to paint).
  static Future<Uint8List> pad(
    Uint8List photo,
    OutpaintPlan plan, {
    ui.Color fill = const ui.Color(0x00000000),
  }) async {
    final image = await decode(photo);
    try {
      final width = image.width + plan.left + plan.right;
      final height = image.height + plan.up + plan.down;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..color = fill,
      );
      canvas.drawImage(
        image,
        ui.Offset(plan.left.toDouble(), plan.up.toDouble()),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(width, height);
      picture.dispose();
      try {
        return await encodePng(out);
      } finally {
        out.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  /// Mask for image-edit APIs: opaque where the photo is, transparent where
  /// the model must paint.
  static Future<Uint8List> mask(Uint8List photo, OutpaintPlan plan) async {
    final image = await decode(photo);
    try {
      final width = image.width + plan.left + plan.right;
      final height = image.height + plan.up + plan.down;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(
          plan.left.toDouble(),
          plan.up.toDouble(),
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        ui.Paint()..color = const ui.Color(0xFF000000),
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(width, height);
      picture.dispose();
      try {
        return await encodePng(out);
      } finally {
        out.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  /// Scales the generated image to cover the padded canvas size, then pastes
  /// the original photo back in the centre so its pixels are never altered.
  static Future<Uint8List> compositeOriginal(
    Uint8List generated,
    Uint8List photo,
    OutpaintPlan plan,
  ) async {
    final result = await decode(generated);
    final original = await decode(photo);
    try {
      final width = original.width + plan.left + plan.right;
      final height = original.height + plan.up + plan.down;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final scale = _coverScale(result, width, height);
      final drawn = ui.Rect.fromCenter(
        center: ui.Offset(width / 2, height / 2),
        width: result.width * scale,
        height: result.height * scale,
      );
      canvas.drawImageRect(
        result,
        ui.Rect.fromLTWH(
          0,
          0,
          result.width.toDouble(),
          result.height.toDouble(),
        ),
        drawn,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.drawImage(
        original,
        ui.Offset(plan.left.toDouble(), plan.up.toDouble()),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final out = await picture.toImage(width, height);
      picture.dispose();
      try {
        return await encodePng(out);
      } finally {
        out.dispose();
      }
    } finally {
      result.dispose();
      original.dispose();
    }
  }

  static double _coverScale(ui.Image image, int width, int height) {
    final sx = width / image.width, sy = height / image.height;
    return sx > sy ? sx : sy;
  }
}
