import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/timo_colors.dart';
import '../constants.dart';
import 'bloom.dart';
import 'effect_frame.dart';
import 'volumetric_light.dart';

Offset _parallaxPx(EffectFrame f) => f.tilt * f.parallax;

// ─── Smog ───────────────────────────────────────────────────────────────────

/// Noise-driven haze that slowly rolls across the stage.
class SmogPass extends EffectPass {
  SmogPass({
    required this.color,
    this.density = 0.3,
    this.flow = const Offset(0.05, -0.03),
    this.bottomBias = 0.65,
  });
  final Color color;
  final double density, bottomBias;
  final Offset flow;
  final _slot = ShaderSlot();
  final _paint = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size, EffectFrame f) {
    if (!f.settings.smog) return;
    final shader = _slot.of(f.programs.smog);
    final rect = Offset.zero & size;
    if (shader == null) {
      // Fallback: a static floor haze so the composition keeps its depth.
      _paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: density * 0.5),
        ],
      ).createShader(rect);
      canvas.drawRect(rect, _paint);
      return;
    }
    final tilt = f.tilt / ViewerConstants.maxTilt;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, f.time)
      ..setFloat(3, tilt.dx)
      ..setFloat(4, tilt.dy)
      ..setFloat(5, color.r)
      ..setFloat(6, color.g)
      ..setFloat(7, color.b)
      ..setFloat(8, density)
      ..setFloat(9, f.settings.smogOctaves.toDouble())
      ..setFloat(10, flow.dx * (0.5 + f.energy))
      ..setFloat(11, flow.dy * (0.5 + f.energy))
      ..setFloat(12, bottomBias);
    _paint.shader = shader;
    canvas.drawRect(rect, _paint);
  }

  @override
  void dispose() => _slot.dispose();
}

// ─── Particles ─────────────────────────────────────────────────────────────

enum ParticleMode { confetti, dust }

/// Cell-hashed GPU particle field: positions, sizes, spin, fall speed and
/// sway are all derived in the shader. The CPU only uploads uniforms.
class ParticlePass extends EffectPass {
  ParticlePass.confetti({
    this.opacity = 1,
    this.scale = 1,
    this.seed = 1,
    this.depthLo = 0,
    this.depthHi = 1,
    this.maxLayers = 3,
  }) : mode = ParticleMode.confetti,
       cell = 46,
       speed = 62,
       lit = false;
  ParticlePass.dust({
    this.opacity = 0.7,
    this.scale = 1,
    this.seed = 7,
    this.depthLo = 0,
    this.depthHi = 1,
    this.maxLayers = 2,
    this.lit = false,
  }) : mode = ParticleMode.dust,
       cell = 84,
       speed = -13;
  final ParticleMode mode;
  final double opacity, scale, seed, cell, speed;

  /// Dust only: confine motes to the volumetric light cone, tint them with
  /// the light and let [EffectFrame.volumetric] drive amount and speed.
  final bool lit;

  /// Depth band this pass covers (0 far .. 1 near) and its layer budget.
  final double depthLo, depthHi;
  final int maxLayers;
  final _slot = ShaderSlot();
  final _paint = Paint();
  _CpuConfetti? _fallback;

  @override
  void paint(Canvas canvas, Size size, EffectFrame f) {
    if (mode == ParticleMode.dust && !f.settings.dust) return;
    final shader = _slot.of(f.programs.particles);
    if (shader == null) {
      if (mode == ParticleMode.confetti) {
        (_fallback ??= _CpuConfetti(seed.toInt())).paint(canvas, size, f);
      }
      return;
    }
    final layers = math.min(maxLayers, f.settings.particleLayers);
    final px = _parallaxPx(f);
    final v = f.volumetric;
    final speedScale = lit ? 0.7 * v.dustSpeed : 1.0;
    final amount = lit ? v.dustAmount * 1.4 : 1.0;
    final light = v.lightPx(size, px);
    final tint = lit ? Color.lerp(Colors.white, v.color, 0.6)! : Colors.white;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, f.time)
      ..setFloat(3, px.dx)
      ..setFloat(4, px.dy)
      ..setFloat(5, layers.toDouble())
      ..setFloat(6, cell)
      ..setFloat(7, speed * speedScale * (1 + 1.5 * f.burst))
      ..setFloat(8, mode == ParticleMode.dust ? 1 : 0)
      ..setFloat(9, scale)
      ..setFloat(
        10,
        opacity * amount * f.settings.particleOpacity * (1 + 0.6 * f.burst),
      )
      ..setFloat(11, seed)
      ..setFloat(12, depthLo)
      ..setFloat(13, depthHi)
      ..setFloat(14, light.dx)
      ..setFloat(15, light.dy)
      ..setFloat(16, v.direction)
      ..setFloat(17, v.spread)
      ..setFloat(18, lit ? 1 : 0)
      // Slow sparkle so lit dust reads as drifting, not blinking.
      ..setFloat(19, lit ? 0.35 : 1)
      ..setFloat(20, tint.r)
      ..setFloat(21, tint.g)
      ..setFloat(22, tint.b);
    _paint
      ..shader = shader
      ..blendMode = mode == ParticleMode.dust
          ? BlendMode.plus
          : BlendMode.srcOver;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  void dispose() => _slot.dispose();
}

/// CPU confetti for devices without fragment shader support. Fixed pool,
/// no per-frame allocation, off-screen slips skipped.
class _CpuConfetti {
  _CpuConfetti(int seed) {
    final r = math.Random(seed);
    for (var i = 0; i < _count; i++) {
      _x[i] = (i * 0.618034) % 1;
      _speed[i] = 0.10 + r.nextDouble() * 0.12;
      _phase[i] = r.nextDouble();
      _spin[i] = (r.nextBool() ? 1 : -1) * (1.4 + r.nextDouble() * 2.4);
      _depth[i] = r.nextDouble();
      _size[i] = 3.2 + r.nextDouble() * 3.0;
      _color[i] = _palette[i % _palette.length];
    }
  }
  static const _count = 72;
  static const _palette = [
    TimoColors.gold,
    TimoColors.magenta,
    TimoColors.cyan,
    Color(0xFFFFFFFF),
    TimoColors.accentSoft,
    Color(0xFFFDE68A),
  ];
  final _x = List<double>.filled(_count, 0);
  final _speed = List<double>.filled(_count, 0);
  final _phase = List<double>.filled(_count, 0);
  final _spin = List<double>.filled(_count, 0);
  final _depth = List<double>.filled(_count, 0);
  final _size = List<double>.filled(_count, 0);
  final _color = List<Color>.filled(_count, Colors.white);
  final _paint = Paint();

  void paint(Canvas canvas, Size size, EffectFrame f) {
    final px = _parallaxPx(f);
    final t = f.time;
    for (var i = 0; i < _count; i++) {
      final fall = (_phase[i] + t * _speed[i]) % 1;
      final y = fall * (size.height + 48) - 24 + px.dy * (0.4 + _depth[i]);
      if (y < -12 || y > size.height + 12) continue;
      final sway = math.sin(t * 1.3 + _phase[i] * math.pi * 2) * 16;
      final x =
          ((_x[i] * size.width + sway * (0.5 + _depth[i])) % size.width) +
          px.dx * (0.4 + _depth[i] * 1.6);
      final rot = t * _spin[i] + _phase[i] * math.pi * 2;
      final flutter = math.cos(rot * 1.7).abs().clamp(0.18, 1.0);
      final s = 0.6 + _depth[i] * 0.8;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      canvas.scale(1, flutter);
      _paint.color = _color[i].withValues(alpha: 0.55 + 0.45 * _depth[i]);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: _size[i] * s,
          height: _size[i] * 2.2 * s,
        ),
        _paint,
      );
      canvas.restore();
    }
  }
}

// ─── Volumetric light ──────────────────────────────────────────────────────

/// One moving-head fixture. Positions are fractions of the card width.
class LightHead {
  const LightHead({
    required this.x,
    required this.sweep,
    required this.speed,
    required this.phase,
    required this.halfWidth,
    required this.colorA,
    required this.colorB,
    this.colorSpeed = 0.35,
    this.intensity = 1,
  });
  final double x, sweep, speed, phase, halfWidth, colorSpeed, intensity;
  final Color colorA, colorB;
}

/// Analytic light cones with fBm smoke scattering, rendered in one shader.
class VolumetricPass extends EffectPass {
  VolumetricPass({required this.heads, this.haze = 0.85})
    : assert(heads.length <= 3);
  final List<LightHead> heads;
  final double haze;
  final _slot = ShaderSlot();
  final _paint = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size, EffectFrame f) {
    final shader = _slot.of(f.programs.volumetric);
    final px = _parallaxPx(f);
    if (shader == null) {
      _fallback(canvas, size, f, px);
      return;
    }
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, f.time)
      ..setFloat(3, px.dx)
      ..setFloat(4, px.dy);
    for (var i = 0; i < 3; i++) {
      final base = 5 + i * 4;
      final colorBase = 17 + i * 3;
      if (i >= heads.length) {
        shader
          ..setFloat(base, 0)
          ..setFloat(base + 1, 0)
          ..setFloat(base + 2, 1)
          ..setFloat(base + 3, 0)
          ..setFloat(colorBase, 0)
          ..setFloat(colorBase + 1, 0)
          ..setFloat(colorBase + 2, 0);
        continue;
      }
      final h = heads[i];
      final headX = size.width * h.x;
      final aim =
          headX + size.width * h.sweep * math.sin(f.time * h.speed + h.phase);
      final color = _colorAt(h, f.time);
      shader
        ..setFloat(base, headX)
        ..setFloat(base + 1, aim)
        ..setFloat(base + 2, size.width * h.halfWidth)
        ..setFloat(base + 3, h.intensity)
        ..setFloat(colorBase, color.r)
        ..setFloat(colorBase + 1, color.g)
        ..setFloat(colorBase + 2, color.b);
    }
    shader
      ..setFloat(26, f.settings.volumetricOctaves.toDouble())
      ..setFloat(27, haze);
    _paint.shader = shader;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  Color _colorAt(LightHead h, double time) => Color.lerp(
    h.colorA,
    h.colorB,
    0.5 + 0.5 * math.sin(time * h.colorSpeed + h.phase * 1.7),
  )!;

  /// Gradient wedges when the shader is unavailable.
  void _fallback(Canvas canvas, Size size, EffectFrame f, Offset px) {
    final w = size.width, h = size.height;
    for (final head in heads) {
      final headX = w * head.x + px.dx * 0.6;
      final aim =
          headX + w * head.sweep * math.sin(f.time * head.speed + head.phase);
      final half = w * head.halfWidth;
      final color = _colorAt(head, f.time);
      final cone = Path()
        ..moveTo(headX - 5, -4)
        ..lineTo(headX + 5, -4)
        ..lineTo(aim + half, h + 8)
        ..lineTo(aim - half, h + 8)
        ..close();
      _paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.42 * head.intensity),
          color.withValues(alpha: 0.1 * head.intensity),
          color.withValues(alpha: 0),
        ],
      ).createShader(cone.getBounds());
      canvas.drawPath(cone, _paint);
    }
  }

  @override
  void dispose() => _slot.dispose();
}

// ─── God rays ──────────────────────────────────────────────────────────────

/// Which side of the person this slice of the volumetric light is drawn on.
enum GodRaysSection { behind, front }

/// One warm fixture above/behind the stage: analytic cone, noise-driven
/// shafts and a drifting scattering medium in a single shader. Drawn twice
/// per ticket — full strength behind the person (the silhouette occludes
/// it), and as a faint medium-only layer in front so the person stands in
/// the haze instead of on top of it.
class GodRaysPass extends EffectPass {
  GodRaysPass({this.section = GodRaysSection.behind});
  final GodRaysSection section;
  final _slot = ShaderSlot();
  final _paint = Paint()..blendMode = BlendMode.plus;

  bool get _front => section == GodRaysSection.front;

  @override
  void paint(Canvas canvas, Size size, EffectFrame f) {
    final v = f.volumetric;
    // The front medium is the cheapest thing to drop on weak devices.
    if (_front && !f.settings.smog) return;
    final intensity = _front ? v.intensity * v.frontHaze : v.intensity;
    if (intensity <= 0) return;
    final px = _parallaxPx(f);
    final shader = _slot.of(f.programs.godRays);
    if (shader == null) {
      _fallback(canvas, size, v, intensity, px);
      return;
    }
    final light = v.lightPx(size, px);
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, f.time)
      ..setFloat(3, px.dx)
      ..setFloat(4, px.dy)
      ..setFloat(5, light.dx)
      ..setFloat(6, light.dy)
      ..setFloat(7, v.direction)
      ..setFloat(8, v.spread)
      ..setFloat(9, v.color.r)
      ..setFloat(10, v.color.g)
      ..setFloat(11, v.color.b)
      ..setFloat(12, intensity)
      ..setFloat(13, v.fogDensity)
      ..setFloat(14, v.shaftScale)
      ..setFloat(15, f.settings.volumetricOctaves.toDouble())
      ..setFloat(16, v.reach)
      ..setFloat(17, _front ? 1 : 0);
    _paint.shader = shader;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  /// Gradient wedge when the shader is unavailable: same cone, no shafts.
  void _fallback(
    Canvas canvas,
    Size size,
    VolumetricLightParams v,
    double intensity,
    Offset px,
  ) {
    final light = v.lightPx(size, px);
    final reach = size.height * (v.reach + 0.6);
    final left =
        light +
        Offset.fromDirection(math.pi / 2 + v.direction - v.spread, reach);
    final right =
        light +
        Offset.fromDirection(math.pi / 2 + v.direction + v.spread, reach);
    final cone = Path()
      ..moveTo(light.dx, light.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    final peak = (_front ? 0.12 : 0.30) * intensity;
    _paint.shader = RadialGradient(
      center: Alignment.center,
      radius: 1,
      colors: [
        v.color.withValues(alpha: peak),
        v.color.withValues(alpha: peak * 0.35),
        v.color.withValues(alpha: 0),
      ],
      stops: const [0, 0.45, 1],
    ).createShader(Rect.fromCircle(center: light, radius: reach));
    canvas.drawPath(cone, _paint);
  }

  @override
  void dispose() => _slot.dispose();
}

// ─── Laser beams ───────────────────────────────────────────────────────────

/// Thin beams with a bloom composite instead of per-stroke mask blurs:
/// all emissive strokes render into one blurred additive layer.
class BeamPass extends EffectPass {
  BeamPass();
  static const _colors = [
    TimoColors.accent,
    TimoColors.cyan,
    TimoColors.magenta,
    TimoColors.gold,
    TimoColors.violet,
  ];
  final _bloom = BloomCompositor();
  final _core = Paint()
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final _body = Paint()
    ..strokeWidth = 5.5
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;
  final _dot = Paint()..blendMode = BlendMode.plus;
  final _origins = List<Offset>.filled(_colors.length, Offset.zero);
  final _targets = List<Offset>.filled(_colors.length, Offset.zero);
  final _strobe = List<double>.filled(_colors.length, 1);

  @override
  void paint(Canvas canvas, Size size, EffectFrame f) {
    final w = size.width, h = size.height;
    final px = _parallaxPx(f);
    for (var i = 0; i < _colors.length; i++) {
      _origins[i] = Offset(w * (0.1 + 0.2 * i) + px.dx * 0.5, -6);
      final sweep = math.sin(f.time * (0.75 + i * 0.13) + i * 1.3);
      _targets[i] = Offset(w * (0.5 + 0.46 * sweep), h + 4);
      _strobe[i] = 0.72 + 0.28 * math.sin(f.time * 6.5 + i * 2.0);
    }
    _bloom.paint(canvas, size, f.settings, _emissive);
  }

  void _emissive(Canvas canvas) {
    for (var i = 0; i < _colors.length; i++) {
      final color = _colors[i];
      final strobe = _strobe[i];
      _body.color = color.withValues(alpha: 0.48 * strobe);
      _core.color = Color.lerp(
        color,
        Colors.white,
        0.6,
      )!.withValues(alpha: 0.95 * strobe);
      canvas.drawLine(_origins[i], _targets[i], _body);
      canvas.drawLine(_origins[i], _targets[i], _core);
      _dot.color = color.withValues(alpha: 0.9 * strobe);
      canvas.drawCircle(_origins[i], 4, _dot);
      _dot.color = color.withValues(alpha: 0.5 * strobe);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_targets[i].dx, _targets[i].dy - 8),
          width: 34,
          height: 9,
        ),
        _dot,
      );
    }
  }
}
