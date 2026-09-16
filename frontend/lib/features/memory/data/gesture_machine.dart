import 'dart:math';

import '../constants.dart';

enum GestureMode { idle, pending, dragging, immersive }

class GestureMachine {
  GestureMode mode = GestureMode.idle;
  Point<double> origin = const Point(0, 0);
  Point<double> delta = const Point(0, 0);
  void down(double x, double y) {
    mode = GestureMode.pending;
    origin = Point(x, y);
    delta = const Point(0, 0);
  }

  bool move(double x, double y) {
    delta = Point(x - origin.x, y - origin.y);
    if (mode != GestureMode.idle &&
        delta.distanceTo(const Point(0, 0)) >
            ImmersiveConstants.moveTolerance) {
      final wasImmersive = mode == GestureMode.immersive;
      mode = GestureMode.dragging;
      return wasImmersive;
    }
    return false;
  }

  bool hold() {
    if (mode != GestureMode.pending) return false;
    mode = GestureMode.immersive;
    return true;
  }

  bool up() {
    final flip =
        mode == GestureMode.dragging &&
        delta.x.abs() >= ImmersiveConstants.flipThreshold &&
        delta.x.abs() > delta.y.abs();
    mode = GestureMode.idle;
    return flip;
  }

  void cancel() => mode = GestureMode.idle;
}
