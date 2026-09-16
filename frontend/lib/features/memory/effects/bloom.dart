import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'effect_quality.dart';

/// HDR-style bloom on Impeller without an offscreen texture round-trip:
/// the emissive geometry is drawn into a `saveLayer` whose paint carries a
/// GPU gaussian blur and additive blend, then drawn again sharp on top.
/// Drawing only emissive things into the layer is the "bright pass"; the
/// wide + tight sigmas approximate a two-level blur pyramid.
class BloomCompositor {
  final _wide = Paint()..blendMode = BlendMode.plus;
  final _tight = Paint()..blendMode = BlendMode.plus;
  double _wideSigma = -1, _tightSigma = -1;

  void _configure(Paint paint, double sigma, double current, double alpha) {
    if (sigma != current) {
      paint.imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      );
    }
    paint.color = Color.fromRGBO(255, 255, 255, alpha);
  }

  void paint(
    Canvas canvas,
    Size size,
    EffectSettings settings,
    void Function(Canvas canvas) emissive, {
    double intensity = 1,
  }) {
    final bounds = Offset.zero & size;
    if (settings.bloomWideSigma > 0) {
      _configure(_wide, settings.bloomWideSigma, _wideSigma, 0.6 * intensity);
      _wideSigma = settings.bloomWideSigma;
      canvas.saveLayer(bounds, _wide);
      emissive(canvas);
      canvas.restore();
    }
    if (settings.bloomSigma > 0) {
      _configure(_tight, settings.bloomSigma, _tightSigma, 0.95 * intensity);
      _tightSigma = settings.bloomSigma;
      canvas.saveLayer(bounds, _tight);
      emissive(canvas);
      canvas.restore();
    }
    emissive(canvas);
  }
}
