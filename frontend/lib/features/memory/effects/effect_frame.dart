import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'effect_quality.dart';
import 'volumetric_light.dart';

/// Compiled programs shared by every pass. Each pass creates its own
/// [ui.FragmentShader] instance from these so per-pass uniforms never
/// clobber each other inside one frame.
class EffectPrograms {
  const EffectPrograms({
    this.smog,
    this.particles,
    this.volumetric,
    this.godRays,
  });
  final ui.FragmentProgram? smog, particles, volumetric, godRays;
  static const none = EffectPrograms();

  EffectPrograms copyWith({
    ui.FragmentProgram? smog,
    ui.FragmentProgram? particles,
    ui.FragmentProgram? volumetric,
    ui.FragmentProgram? godRays,
  }) => EffectPrograms(
    smog: smog ?? this.smog,
    particles: particles ?? this.particles,
    volumetric: volumetric ?? this.volumetric,
    godRays: godRays ?? this.godRays,
  );
}

/// Everything a pass needs for one frame. Immutable, built once per paint.
class EffectFrame {
  const EffectFrame({
    required this.time,
    required this.tilt,
    required this.settings,
    required this.programs,
    this.energy = 0.35,
    this.burst = 0,
    this.parallax = 2.0,
    this.volumetric = VolumetricLightParams.defaults,
  });

  /// Live tunables of the volumetric light effect.
  final VolumetricLightParams volumetric;

  /// Multiplier from tilt units to px for this layer's parallax.
  final double parallax;

  /// Ambient channels (see AmbientMotion): smog drifts faster with energy,
  /// particles surge with burst.
  final double energy, burst;

  /// Seconds since the layer started.
  final double time;

  /// Card tilt in tilt units (±ViewerConstants.maxTilt).
  final Offset tilt;
  final EffectSettings settings;
  final EffectPrograms programs;
}

/// One independently toggleable visual layer (smog, particles, light...).
abstract class EffectPass {
  void paint(Canvas canvas, Size size, EffectFrame frame);
  void dispose() {}
}

/// Keeps one shader instance per pass, rebuilt only when the program
/// object changes (first load).
class ShaderSlot {
  ui.FragmentShader? _shader;
  ui.FragmentProgram? _program;

  ui.FragmentShader? of(ui.FragmentProgram? program) {
    if (program == null) return null;
    if (!identical(program, _program)) {
      _shader?.dispose();
      _shader = program.fragmentShader();
      _program = program;
    }
    return _shader;
  }

  void dispose() {
    _shader?.dispose();
    _shader = null;
    _program = null;
  }
}
