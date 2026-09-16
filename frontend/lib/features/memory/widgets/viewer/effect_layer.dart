import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../effects/effect_quality.dart';
import '../../effects/paint_watchdog.dart';
import '../../motion/ambient_motion.dart';
import '../../motion/motion_tokens.dart';
import '../../effects/shader_cache.dart';
import '../../models/ticket_effect.dart';
import '../../constants.dart';
import '../../effects/effect_frame.dart';
import '../../effects/stage_effects.dart';
import '../../effects/volumetric_light.dart';

/// Animated stage effect. Drives a clock, loads the effect programs once,
/// and repaints through listenables only — no widget rebuild per frame.
/// [tilt] (tilt units) adds parallax; the quality tier comes from
/// [EffectQualityController].
class EffectLayer extends StatefulWidget {
  const EffectLayer({
    super.key,
    required this.effect,
    this.tilt,
    this.depth = EffectDepth.full,
    this.parallax = 2.0,
  });
  final TicketEffect effect;
  final ValueListenable<Offset>? tilt;

  /// Which slice of the effect this layer draws (behind/in front of the
  /// person, or everything).
  final EffectDepth depth;

  /// Tilt units → px for this layer's parallax.
  final double parallax;
  static const shaderAssets = (
    smog: 'shaders/smog.frag',
    particles: 'shaders/particles.frag',
    volumetric: 'shaders/volumetric.frag',
    godRays: 'shaders/god_rays.frag',
  );
  @override
  State<EffectLayer> createState() => _EffectLayerState();
}

class _EffectLayerState extends State<EffectLayer>
    with SingleTickerProviderStateMixin {
  final time = ValueNotifier<double>(ViewerConstants.staticEffectTime);
  final quality = EffectQualityController.instance;
  final volumetric = VolumetricLightController.instance;

  /// Stops the clock while the layer is not being painted (scrolled out of
  /// a viewport, covered) and resumes it on the next paint. [timeBase]
  /// keeps the clock continuous across the restart so the haze never jumps.
  final watchdog = PaintWatchdog();
  double timeBase = 0;
  late StageEffect stage = StageEffect.of(widget.effect, depth: widget.depth);
  EffectPrograms programs = EffectPrograms.none;
  Ticker? ticker;

  @override
  void initState() {
    super.initState();
    quality.startAdaptive();
    if (widget.effect != TicketEffect.none) loadPrograms();
  }

  Future<void> loadPrograms() async {
    final assets = EffectLayer.shaderAssets;
    Future<ui.FragmentProgram?> load(String asset) =>
        ShaderCache.load(asset)
            .then<ui.FragmentProgram?>((p) => p, onError: (Object _) => null);
    final loaded = await Future.wait([
      load(assets.smog),
      load(assets.particles),
      load(assets.volumetric),
      load(assets.godRays),
    ]);
    if (!mounted) return;
    setState(() {
      programs = EffectPrograms(
        smog: loaded[0],
        particles: loaded[1],
        volumetric: loaded[2],
        godRays: loaded[3],
      );
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    stage.dispose();
    stage = StageEffect.of(widget.effect, depth: widget.depth);
  }

  @override
  void didUpdateWidget(EffectLayer old) {
    super.didUpdateWidget(old);
    if (old.effect != widget.effect || old.depth != widget.depth) {
      stage.dispose();
      stage = StageEffect.of(widget.effect, depth: widget.depth);
      if (programs == EffectPrograms.none &&
          widget.effect != TicketEffect.none) {
        loadPrograms();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !Motion.reduced(context) && widget.effect != TicketEffect.none;
    if (animate && ticker == null) {
      ticker = createTicker(onTick)..start();
    } else if (!animate) {
      ticker?.dispose();
      ticker = null;
    }
  }

  void onTick(Duration elapsed) {
    time.value = timeBase + elapsed.inMicroseconds / 1e6;
    if (watchdog.tick()) {
      timeBase = time.value;
      ticker?.stop();
    }
  }

  /// Called by the painter. A paint after dormancy means the layer is on
  /// screen again; the clock restarts once this frame is done.
  void onPainted() {
    if (!watchdog.painted()) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final t = ticker;
      if (mounted && t != null && !t.isActive) t.start();
    });
  }

  @override
  void dispose() {
    ticker?.dispose();
    time.dispose();
    stage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _EffectPainter(
          stage: stage,
          programs: programs,
          time: time,
          tilt: widget.tilt,
          quality: quality,
          volumetric: volumetric,
          parallax: widget.parallax,
          onPainted: onPainted,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _EffectPainter extends CustomPainter {
  _EffectPainter({
    required this.stage,
    required this.programs,
    required this.time,
    required this.tilt,
    required this.quality,
    required this.volumetric,
    required this.parallax,
    required this.onPainted,
  }) : super(
         repaint: Listenable.merge([
           time,
           ?tilt,
           quality,
           volumetric,
           AmbientMotion.instance,
         ]),
       );
  final StageEffect stage;
  final EffectPrograms programs;
  final ValueListenable<double> time;
  final ValueListenable<Offset>? tilt;
  final EffectQualityController quality;
  final ValueListenable<VolumetricLightParams> volumetric;
  final double parallax;
  final VoidCallback onPainted;

  @override
  void paint(Canvas canvas, Size size) {
    if (stage.passes.isEmpty) return;
    onPainted();
    canvas.clipRect(Offset.zero & size);
    stage.paint(
      canvas,
      size,
      EffectFrame(
        time: time.value,
        tilt: tilt?.value ?? Offset.zero,
        settings: quality.settings,
        programs: programs,
        energy: AmbientMotion.instance.energy,
        burst: AmbientMotion.instance.burst,
        parallax: parallax,
        volumetric: volumetric.value,
      ),
    );
  }

  @override
  bool shouldRepaint(_EffectPainter old) =>
      old.stage != stage ||
      old.programs != programs ||
      old.tilt != tilt ||
      old.parallax != parallax;
}
