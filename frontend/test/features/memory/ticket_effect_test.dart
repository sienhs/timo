import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/effects/effect_frame.dart';
import 'package:timo/features/memory/effects/effect_passes.dart';
import 'package:timo/features/memory/effects/stage_effects.dart';
import 'package:timo/features/memory/effects/effect_quality.dart';
import 'package:timo/features/memory/models/ticket_effect.dart';

void main() {
  test('persisted Korean labels round-trip and unknown labels fall back', () {
    for (final effect in TicketEffect.values) {
      expect(TicketEffect.fromLabel(effect.label), effect);
    }
    expect(TicketEffect.fromLabel('없는 효과'), TicketEffect.none);
    expect(TicketEffect.fromLabel('커튼과 스포트라이트'), TicketEffect.curtain);
    expect(TicketEffect.values.map((e) => e.label), [
      '꽃가루',
      '레이저',
      '무대 조명',
      '스포트라이트',
      '빛줄기',
      '효과 없음',
    ]);
  });

  test('every stage effect paints its fallback path at every quality', () {
    for (final effect in TicketEffect.values) {
      for (final quality in EffectQuality.values) {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final stage = StageEffect.of(effect);
        stage.paint(
          canvas,
          const Size(300, 460),
          EffectFrame(
            time: 2.3,
            tilt: const Offset(4, -3),
            settings: EffectSettings.of(quality),
            programs: EffectPrograms.none,
          ),
        );
        stage.dispose();
        recorder.endRecording().dispose();
      }
    }
  });

  test('behind/front layers split every effect around the person', () {
    for (final effect in TicketEffect.values) {
      if (effect == TicketEffect.none) continue;
      final behind = StageEffect.of(effect, depth: EffectDepth.behind);
      final front = StageEffect.of(effect, depth: EffectDepth.front);
      final full = StageEffect.of(effect);
      expect(behind.passes, isNotEmpty, reason: '${effect.label} behind');
      expect(front.passes, isNotEmpty, reason: '${effect.label} front');
      // Heavy passes (smog, light, beams) never sit in front; the only
      // exception is the faint volumetric medium, which the low tier skips.
      expect(
        front.passes.every(
          (p) =>
              p is ParticlePass ||
              (p is GodRaysPass && p.section == GodRaysSection.front),
        ),
        true,
        reason: '${effect.label} front must be particles or front haze only',
      );
      expect(full.passes.length, greaterThanOrEqualTo(behind.passes.length));
      for (final s in [behind, front, full]) {
        s.dispose();
      }
    }
  });

  test('quality tiers only ever get cheaper', () {
    const tiers = [
      EffectSettings.high,
      EffectSettings.medium,
      EffectSettings.low,
    ];
    for (var i = 1; i < tiers.length; i++) {
      expect(
        tiers[i].particleLayers,
        lessThanOrEqualTo(tiers[i - 1].particleLayers),
      );
      expect(tiers[i].smogOctaves, lessThanOrEqualTo(tiers[i - 1].smogOctaves));
      expect(tiers[i].bloomSigma, lessThanOrEqualTo(tiers[i - 1].bloomSigma));
    }
    expect(EffectSettings.low.bloomSigma, 0);
  });
}
