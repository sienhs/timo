import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Rendering tier for GPU effects. Mirrors the vGPU "Adaptive Quality"
/// idea: pick a pipeline from device performance instead of one fixed cost.
enum EffectQuality { low, medium, high }

/// Knobs every effect pass reads. One place to tune cost per tier.
class EffectSettings {
  const EffectSettings({
    required this.particleLayers,
    required this.particleOpacity,
    required this.smogOctaves,
    required this.volumetricOctaves,
    required this.bloomSigma,
    required this.bloomWideSigma,
    required this.dust,
    required this.smog,
  });

  /// Depth layers evaluated per pixel by the particle shader (1..3).
  final int particleLayers;
  final double particleOpacity;

  /// fBm octaves for smog / volumetric noise (2..5).
  final int smogOctaves;
  final int volumetricOctaves;

  /// Gaussian sigma of the bloom pass; 0 disables bloom.
  final double bloomSigma;

  /// Second, wider and dimmer bloom pass; 0 disables it.
  final double bloomWideSigma;
  final bool dust;
  final bool smog;

  static const high = EffectSettings(
    particleLayers: 3,
    particleOpacity: 1,
    smogOctaves: 4,
    volumetricOctaves: 3,
    bloomSigma: 6,
    bloomWideSigma: 18,
    dust: true,
    smog: true,
  );
  static const medium = EffectSettings(
    particleLayers: 2,
    particleOpacity: 1,
    smogOctaves: 3,
    volumetricOctaves: 2,
    bloomSigma: 6,
    bloomWideSigma: 0,
    dust: true,
    smog: true,
  );
  static const low = EffectSettings(
    particleLayers: 1,
    particleOpacity: 0.9,
    smogOctaves: 2,
    volumetricOctaves: 2,
    bloomSigma: 0,
    bloomWideSigma: 0,
    dust: false,
    smog: false,
  );

  static EffectSettings of(EffectQuality quality) => switch (quality) {
    EffectQuality.high => high,
    EffectQuality.medium => medium,
    EffectQuality.low => low,
  };
}

/// Watches frame timings and steps the tier down when the device cannot
/// hold the budget. Never steps back up on its own: a stable frame rate
/// beats a flickering one. [lock] pins a tier (settings screen, tests).
class EffectQualityController extends ValueNotifier<EffectQuality> {
  EffectQualityController._() : super(EffectQuality.high);
  static final instance = EffectQualityController._();

  /// Frame budget for 60fps with headroom for UI work.
  static const frameBudget = Duration(milliseconds: 18);
  static const window = 45;
  static const slowRatio = 0.4;
  static const cooldown = Duration(seconds: 3);

  bool _locked = false, _listening = false;
  int _frames = 0, _slow = 0;
  DateTime _lastChange = DateTime.fromMillisecondsSinceEpoch(0);

  EffectSettings get settings => EffectSettings.of(value);

  /// Starts sampling frame timings. Safe to call more than once.
  void startAdaptive() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void lock(EffectQuality quality) {
    _locked = true;
    value = quality;
  }

  void unlock() => _locked = false;

  void _onTimings(List<FrameTiming> timings) {
    if (_locked || value == EffectQuality.low) return;
    for (final t in timings) {
      _frames++;
      final cost = t.buildDuration > t.rasterDuration
          ? t.buildDuration
          : t.rasterDuration;
      if (cost > frameBudget) _slow++;
    }
    if (_frames < window) return;
    final ratio = _slow / _frames;
    _frames = 0;
    _slow = 0;
    final now = DateTime.now();
    if (ratio > slowRatio && now.difference(_lastChange) > cooldown) {
      _lastChange = now;
      value = value == EffectQuality.high
          ? EffectQuality.medium
          : EffectQuality.low;
    }
  }
}
