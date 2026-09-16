import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/utils/palette_extractor.dart';

ByteData _pixels(List<Color> colors) {
  final data = ByteData(colors.length * 4);
  for (var i = 0; i < colors.length; i++) {
    final c = colors[i];
    data
      ..setUint8(i * 4, (c.r * 255).round())
      ..setUint8(i * 4 + 1, (c.g * 255).round())
      ..setUint8(i * 4 + 2, (c.b * 255).round())
      ..setUint8(i * 4 + 3, 255);
  }
  return data;
}

double _hue(Color c) => HSVColor.fromColor(c).hue;

void main() {
  test('dominant blue stage with magenta lights yields blue then magenta', () {
    final pixels = [
      for (var i = 0; i < 60; i++) const Color(0xFF1E4FD8),
      for (var i = 0; i < 25; i++) const Color(0xFFE0409A),
      for (var i = 0; i < 40; i++) const Color(0xFF101010), // dark floor
      for (var i = 0; i < 20; i++) const Color(0xFF888888), // grey crowd
    ];
    final palette = PaletteExtractor.fromPixels(_pixels(pixels), pixels.length);
    expect(_hue(palette.primary), closeTo(_hue(const Color(0xFF1E4FD8)), 12));
    expect(_hue(palette.secondary), closeTo(_hue(const Color(0xFFE0409A)), 12));
    expect(HSVColor.fromColor(palette.accent).value, greaterThan(0.9));
  });

  test('greyscale photo falls back to the brand palette', () {
    final pixels = [for (var i = 0; i < 50; i++) const Color(0xFF777777)];
    expect(
      PaletteExtractor.fromPixels(_pixels(pixels), pixels.length),
      TicketPalette.fallback,
    );
  });
}
