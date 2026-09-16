import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/effects/effect_frame.dart';
import 'package:timo/features/memory/effects/effect_passes.dart';
import 'package:timo/features/memory/effects/stage_effects.dart';
import 'package:timo/features/memory/effects/volumetric_light.dart';
import 'package:timo/features/memory/effects/effect_quality.dart';
import 'package:timo/features/memory/effects/paint_watchdog.dart';
import 'package:timo/features/memory/models/ticket_effect.dart';

void main() {
  test(
    'shafts and lit far dust behind the person; medium + near dust in front',
    () {
      final behind = StageEffect.of(
        TicketEffect.godRays,
        depth: EffectDepth.behind,
      );
      final front = StageEffect.of(
        TicketEffect.godRays,
        depth: EffectDepth.front,
      );
      final full = StageEffect.of(TicketEffect.godRays);

      expect(
        behind.passes.whereType<GodRaysPass>().single.section,
        GodRaysSection.behind,
      );
      expect(behind.passes.whereType<ParticlePass>().every((p) => p.lit), true);
      expect(
        behind.passes.whereType<ParticlePass>().single.depthHi,
        lessThan(1),
      );

      expect(
        front.passes.whereType<GodRaysPass>().single.section,
        GodRaysSection.front,
      );
      final near = front.passes.whereType<ParticlePass>().single;
      expect(near.lit, true);
      expect(near.depthLo, greaterThan(0.7));
      expect(near.maxLayers, 1);

      // Preview tiles draw everything in one layer, no separate front medium.
      expect(full.passes.whereType<GodRaysPass>().length, 1);
      for (final s in [behind, front, full]) {
        s.dispose();
      }
    },
  );

  test(
    'every section paints its fallback at every tier and extreme params',
    () {
      const extremes = [
        VolumetricLightParams.defaults,
        VolumetricLightParams(intensity: 0),
        VolumetricLightParams(
          intensity: 1,
          spread: 1.2,
          lightY: 0.3,
          fogDensity: 1,
          dustAmount: 1,
          frontHaze: 0.6,
        ),
        VolumetricLightParams(spread: 0.2, reach: 0.4, shaftScale: 16),
      ];
      for (final depth in EffectDepth.values) {
        for (final quality in EffectQuality.values) {
          for (final params in extremes) {
            final recorder = PictureRecorder();
            final canvas = Canvas(recorder);
            final stage = StageEffect.of(TicketEffect.godRays, depth: depth);
            stage.paint(
              canvas,
              const Size(300, 460),
              EffectFrame(
                time: 12.5,
                tilt: const Offset(-6, 2),
                settings: EffectSettings.of(quality),
                programs: EffectPrograms.none,
                volumetric: params,
              ),
            );
            stage.dispose();
            recorder.endRecording().dispose();
          }
        }
      }
    },
  );

  test('params are value objects and place the fixture above the card', () {
    const a = VolumetricLightParams();
    final b = a.copyWith(intensity: a.intensity);
    final c = a.copyWith(color: const Color(0xFFA9C8FF));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, false);

    final light = a.lightPx(const Size(300, 460), const Offset(4, -2));
    expect(light.dx, closeTo(300 * a.lightX + 4, 1e-9));
    expect(light.dy, lessThan(0), reason: 'fixture sits above the top edge');

    final controller = VolumetricLightController.instance;
    controller.value = c;
    expect(controller.value.color, const Color(0xFFA9C8FF));
    controller.reset();
    expect(controller.value, VolumetricLightParams.defaults);
  });

  test('paint watchdog stops after silent ticks and resumes on paint', () {
    final w = PaintWatchdog(limit: 3);
    // Painting every frame: never dormant.
    for (var i = 0; i < 5; i++) {
      expect(w.tick(), false);
      expect(w.painted(), false);
    }
    // Scrolled away: paints stop, ticks continue.
    expect(w.tick(), false);
    expect(w.tick(), false);
    expect(w.tick(), false);
    expect(w.tick(), true);
    expect(w.dormant, true);
    expect(w.tick(), true);
    // Back on screen: the first paint asks for a restart, once.
    expect(w.painted(), true);
    expect(w.dormant, false);
    expect(w.painted(), false);
    expect(w.tick(), false);
  });
}
