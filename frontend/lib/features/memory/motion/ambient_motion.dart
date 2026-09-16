import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Global ambient parameters that tie UI motion to the GPU backdrop, so the
/// aurora, smog and particles react to what the interface is doing.
///
/// One writer per channel keeps engines from fighting over a value:
/// - `energy`  → route transitions and dialogs (page exit/enter, calm)
/// - `glow`    → primary button press
/// - `focus`   → selection (which card/tile the user picked)
/// - `burst`   → events (ticket created)
///
/// Values ease toward their targets on a private ticker that only runs while
/// something is moving; at rest there is no per-frame work.
class AmbientMotion extends ChangeNotifier implements TickerProvider {
  AmbientMotion._();
  static final instance = AmbientMotion._();

  static const restEnergy = 0.35;
  static const calmEnergy = 0.12;
  static const restFocus = Offset(0.62, 0.8);

  /// Reduced motion: channels stay at rest and every call is a no-op.
  bool enabled = true;

  double energy = restEnergy;
  double glow = 0;
  double burst = 0;
  Offset focus = restFocus;
  double focusStrength = 0;

  double _energyTarget = restEnergy;
  double _glowTarget = 0;
  Offset _focusTarget = restFocus;
  double _focusStrengthTarget = 0;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// Driven directly by a transition animation each frame.
  void setEnergy(double value) {
    if (!enabled) return;
    energy = value.clamp(0.0, 1.0);
    _energyTarget = energy;
    notifyListeners();
  }

  void relaxEnergy() => _target(energy: restEnergy);
  void calm(bool on) => _target(energy: on ? calmEnergy : restEnergy);
  void pressGlow(bool down) => _target(glow: down ? 1.0 : 0.0);

  /// Move the highlight toward a screen position (0..1 normalized).
  void focusOn(Offset normalized) => _target(
    focus: Offset(normalized.dx.clamp(0.0, 1.0), normalized.dy.clamp(0.0, 1.0)),
    focusStrength: 1,
  );
  void clearFocus() => _target(focusStrength: 0);

  /// Momentary surge (particles speed up, aurora flashes), decays on its own.
  void pulse() {
    if (!enabled) return;
    burst = 1;
    _ensureTicking();
    notifyListeners();
  }

  void _target({
    double? energy,
    double? glow,
    Offset? focus,
    double? focusStrength,
  }) {
    if (!enabled) return;
    if (energy != null) _energyTarget = energy;
    if (glow != null) _glowTarget = glow;
    if (focus != null) _focusTarget = focus;
    if (focusStrength != null) _focusStrengthTarget = focusStrength;
    _ensureTicking();
  }

  void _ensureTicking() {
    // Nobody is painting: don't animate into the void, just land.
    if (!hasListeners) {
      _snap();
      return;
    }
    final ticker = _ticker ??= createTicker(_onTick);
    if (!ticker.isActive) {
      _last = Duration.zero;
      ticker.start();
    }
  }

  /// Jump to targets and stop; used when the last painter goes away so no
  /// frame callback outlives the widget tree.
  void _snap() {
    energy = _energyTarget;
    glow = _glowTarget;
    focusStrength = _focusStrengthTarget;
    focus = _focusTarget;
    burst = 0;
    _ticker?.stop();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _snap();
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    step(dt);
  }

  /// One integration step; public so tests can drive it without a ticker.
  @visibleForTesting
  void step(double dt) {
    double approach(double v, double t, double rate) =>
        v + (t - v) * math.min(1, dt * rate);
    energy = approach(energy, _energyTarget, 4);
    glow = approach(glow, _glowTarget, 12);
    focusStrength = approach(focusStrength, _focusStrengthTarget, 5);
    focus = Offset(
      approach(focus.dx, _focusTarget.dx, 5),
      approach(focus.dy, _focusTarget.dy, 5),
    );
    burst *= math.pow(0.03, dt).toDouble();
    if (burst < 0.005) burst = 0;
    final settled =
        (energy - _energyTarget).abs() < 0.002 &&
        (glow - _glowTarget).abs() < 0.002 &&
        (focusStrength - _focusStrengthTarget).abs() < 0.002 &&
        (focus - _focusTarget).distance < 0.002 &&
        burst == 0;
    if (settled) {
      energy = _energyTarget;
      glow = _glowTarget;
      focusStrength = _focusStrengthTarget;
      focus = _focusTarget;
      _ticker?.stop();
    }
    notifyListeners();
  }

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
