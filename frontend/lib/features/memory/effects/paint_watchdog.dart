/// Detects that a continuously animating painter has stopped being painted.
///
/// Flutter skips painting a repaint boundary whose layer is detached — a
/// card scrolled out of a viewport, for instance — while the clock driving
/// it keeps ticking. Count ticks between paints: after [limit] silent ticks
/// the owner should stop its clock ([tick] returns true); the next paint
/// means the widget is visible again and the clock should resume
/// ([painted] returns true).
class PaintWatchdog {
  PaintWatchdog({this.limit = 12});

  /// Silent ticks tolerated before going dormant (≈ 200 ms at 60 fps).
  final int limit;
  int _silent = 0;
  bool _dormant = false;

  bool get dormant => _dormant;

  /// Call once per clock tick. True when the clock should stop.
  bool tick() {
    if (_dormant) return true;
    if (++_silent > limit) _dormant = true;
    return _dormant;
  }

  /// Call from the painter. True when a stopped clock should restart.
  bool painted() {
    _silent = 0;
    if (!_dormant) return false;
    _dormant = false;
    return true;
  }
}
