import 'package:flutter/painting.dart';

import '../models/ticket_effect.dart';
import '../theme/timo_colors.dart';
import 'effect_frame.dart';
import 'effect_passes.dart';

/// Where an effect layer sits relative to the person cut-out.
enum EffectDepth {
  /// Everything in one layer (previews, gallery).
  full,

  /// Between the photo and the person: haze, light cones, beams, far slips.
  behind,

  /// In front of the person: only the nearest, sparse particles.
  front,
}

/// A stage effect is an ordered stack of independent passes (smog,
/// particles, light, geometry). Passes own GPU resources; dispose them.
/// The same effect is split into a behind-person and a front-person layer so
/// the person reads as standing inside the effect rather than under it.
class StageEffect {
  StageEffect(this.passes);
  final List<EffectPass> passes;

  static const _warmHaze = Color(0xFF8C7E9A);
  static const _coolHaze = Color(0xFF3F5B96);
  static const _neutralHaze = Color(0xFF6E7A94);

  static const _movingHeads = [
    LightHead(
      x: 0.2,
      sweep: 0.34,
      speed: 0.6,
      phase: 0,
      halfWidth: 0.19,
      colorA: Color(0xFFFFD27A),
      colorB: TimoColors.cyan,
    ),
    LightHead(
      x: 0.5,
      sweep: 0.3,
      speed: 0.5,
      phase: 2.1,
      halfWidth: 0.17,
      colorA: TimoColors.cyan,
      colorB: TimoColors.magenta,
    ),
    LightHead(
      x: 0.8,
      sweep: 0.34,
      speed: 0.66,
      phase: 4.2,
      halfWidth: 0.19,
      colorA: TimoColors.magenta,
      colorB: Color(0xFFFFD27A),
    ),
  ];
  static const _spotlight = [
    LightHead(
      x: 0.5,
      sweep: 0.13,
      speed: 0.7,
      phase: 0.4,
      halfWidth: 0.26,
      colorA: Color(0xFFFFF1C9),
      colorB: Color(0xFFFFE0A6),
      colorSpeed: 0.2,
      intensity: 0.9,
    ),
  ];

  factory StageEffect.of(
    TicketEffect effect, {
    EffectDepth depth = EffectDepth.full,
  }) {
    final behind = depth != EffectDepth.front;
    final front = depth != EffectDepth.behind;
    // Particle depth ranges: the far band lives behind the person, the near
    // band in front; a full layer spans both.
    final farLo = 0.0, farHi = depth == EffectDepth.full ? 1.0 : 0.55;
    const nearLo = 0.78, nearHi = 1.0;
    return switch (effect) {
      TicketEffect.confetti => StageEffect([
        if (behind) ...[
          SmogPass(color: _warmHaze, density: 0.2, bottomBias: 0.7),
          ParticlePass.dust(opacity: 0.45, depthLo: farLo, depthHi: farHi),
          ParticlePass.confetti(depthLo: farLo, depthHi: farHi),
        ],
        if (depth == EffectDepth.front)
          ParticlePass.confetti(
            depthLo: nearLo,
            depthHi: nearHi,
            maxLayers: 1,
            seed: 3,
          ),
      ]),
      TicketEffect.laser => StageEffect([
        if (behind) ...[
          SmogPass(
            color: _coolHaze,
            density: 0.42,
            flow: const Offset(0.08, -0.02),
            bottomBias: 0.5,
          ),
          BeamPass(),
        ],
        if (front)
          ParticlePass.dust(
            opacity: 0.35,
            scale: 0.8,
            depthLo: depth == EffectDepth.full ? farLo : nearLo,
            depthHi: nearHi,
            maxLayers: depth == EffectDepth.full ? 2 : 1,
          ),
      ]),
      TicketEffect.stageLights => StageEffect([
        if (behind) ...[
          SmogPass(color: _neutralHaze, density: 0.28, bottomBias: 0.55),
          VolumetricPass(heads: _movingHeads),
          ParticlePass.dust(depthLo: farLo, depthHi: farHi),
        ],
        if (depth == EffectDepth.front)
          ParticlePass.dust(
            opacity: 0.55,
            depthLo: nearLo,
            depthHi: nearHi,
            maxLayers: 1,
            seed: 11,
          ),
      ]),
      TicketEffect.curtain => StageEffect([
        if (behind) ...[
          VolumetricPass(haze: 0.7, heads: _spotlight),
          ParticlePass.dust(
            opacity: 0.6,
            scale: 0.9,
            depthLo: farLo,
            depthHi: farHi,
          ),
        ],
        if (depth == EffectDepth.front)
          ParticlePass.dust(
            opacity: 0.5,
            scale: 0.9,
            depthLo: nearLo,
            depthHi: nearHi,
            maxLayers: 1,
            seed: 13,
          ),
      ]),
      // Warm light from above/behind: shafts and far dust behind the person,
      // a faint medium and a few near motes in front (see GodRaysPass).
      TicketEffect.godRays => StageEffect([
        if (behind) ...[
          GodRaysPass(),
          ParticlePass.dust(
            opacity: 0.55,
            scale: 1.15,
            depthLo: farLo,
            depthHi: farHi,
            seed: 17,
            lit: true,
          ),
        ],
        if (depth == EffectDepth.front) ...[
          GodRaysPass(section: GodRaysSection.front),
          ParticlePass.dust(
            opacity: 0.32,
            scale: 1.05,
            depthLo: nearLo,
            depthHi: nearHi,
            maxLayers: 1,
            seed: 19,
            lit: true,
          ),
        ],
      ]),
      TicketEffect.none => StageEffect(const []),
    };
  }

  void paint(Canvas canvas, Size size, EffectFrame frame) {
    for (final pass in passes) {
      pass.paint(canvas, size, frame);
    }
  }

  void dispose() {
    for (final pass in passes) {
      pass.dispose();
    }
  }
}
