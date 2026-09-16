import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/timo_colors.dart';

/// Ambient colours derived from a photo: two dominant hues for the backdrop
/// and a bright accent for glows.
class TicketPalette {
  const TicketPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
  });
  final Color primary, secondary, accent;

  static const fallback = TicketPalette(
    primary: Color(0xFF1B3A5C),
    secondary: Color(0xFF3A1F5E),
    accent: TimoColors.accent,
  );
}

/// Hue-histogram palette extraction on a 48px thumbnail. Saturated,
/// reasonably bright pixels vote for their hue bin weighted by saturation;
/// the two strongest well-separated bins become primary/secondary.
/// Results are cached per path for the life of the process.
class PaletteExtractor {
  static const _thumb = 48;
  static const _bins = 24;
  static const _minValue = 0.12;
  static const _minSaturation = 0.18;
  static const _minHueGapBins = 3;
  static final _cache = <String, Future<TicketPalette>>{};

  static Future<TicketPalette> extract(String path) =>
      _cache.putIfAbsent(path, () => _extract(path));

  static Future<TicketPalette> _extract(String path) async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
        targetWidth: _thumb,
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final data = await image.toByteData();
      image.dispose();
      if (data == null) return TicketPalette.fallback;
      return fromPixels(data, image.width * image.height);
    } catch (_) {
      return TicketPalette.fallback;
    }
  }

  /// Pure histogram step, exposed for tests. [pixels] is RGBA8888.
  static TicketPalette fromPixels(ByteData pixels, int count) {
    final weight = List<double>.filled(_bins, 0);
    final r = List<double>.filled(_bins, 0);
    final g = List<double>.filled(_bins, 0);
    final b = List<double>.filled(_bins, 0);
    for (var i = 0; i < count; i++) {
      final o = i * 4;
      if (pixels.getUint8(o + 3) < 128) continue;
      final color = Color.fromARGB(
        255,
        pixels.getUint8(o),
        pixels.getUint8(o + 1),
        pixels.getUint8(o + 2),
      );
      final hsv = HSVColor.fromColor(color);
      if (hsv.value < _minValue || hsv.saturation < _minSaturation) continue;
      final bin = (hsv.hue / 360 * _bins).floor() % _bins;
      final w = hsv.saturation * (0.35 + 0.65 * hsv.value);
      weight[bin] += w;
      r[bin] += color.r * w;
      g[bin] += color.g * w;
      b[bin] += color.b * w;
    }
    var first = -1;
    for (var i = 0; i < _bins; i++) {
      if (first < 0 || weight[i] > weight[first]) first = i;
    }
    if (first < 0 || weight[first] <= 0) return TicketPalette.fallback;
    var second = -1;
    for (var i = 0; i < _bins; i++) {
      final gap = (i - first).abs();
      final distance = gap > _bins / 2 ? _bins - gap : gap;
      if (distance < _minHueGapBins || weight[i] <= 0) continue;
      if (second < 0 || weight[i] > weight[second]) second = i;
    }
    Color average(int bin) => Color.from(
      alpha: 1,
      red: r[bin] / weight[bin],
      green: g[bin] / weight[bin],
      blue: b[bin] / weight[bin],
    );
    final primary = average(first);
    final secondary = second >= 0
        ? average(second)
        : HSVColor.fromColor(primary)
              .withHue((HSVColor.fromColor(primary).hue + 40) % 360)
              .toColor();
    return TicketPalette(
      primary: _ambient(primary),
      secondary: _ambient(secondary),
      accent: _accent(primary),
    );
  }

  /// Deep, saturated version suitable for a dark backdrop light.
  static Color _ambient(Color c) {
    final hsv = HSVColor.fromColor(c);
    return hsv
        .withSaturation((hsv.saturation * 1.15).clamp(0.45, 0.9))
        .withValue(hsv.value.clamp(0.4, 0.7))
        .toColor();
  }

  /// Bright version for glows and highlights.
  static Color _accent(Color c) {
    final hsv = HSVColor.fromColor(c);
    return hsv
        .withSaturation((hsv.saturation * 1.1).clamp(0.55, 0.85))
        .withValue(0.95)
        .toColor();
  }
}
