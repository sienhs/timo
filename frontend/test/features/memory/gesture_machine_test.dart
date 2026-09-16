import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/gesture_machine.dart';

void main() {
  test('450ms callback enters only while pointer is pending', () {
    final g = GestureMachine()..down(0, 0);
    expect(g.hold(), true);
    expect(g.mode, GestureMode.immersive);
    expect(g.up(), false);
  });
  test('movement beyond 10px cancels hold and permits horizontal flip', () {
    final g = GestureMachine()..down(0, 0);
    g.move(11, 0);
    expect(g.hold(), false);
    g.move(90, 4);
    expect(g.up(), true);
  });
  test('moving after hold exits immersive before dragging', () {
    final g = GestureMachine()
      ..down(0, 0)
      ..hold();
    expect(g.move(20, 0), true);
    expect(g.mode, GestureMode.dragging);
  });
  test('vertical and small gestures never flip', () {
    final g = GestureMachine()..down(0, 0);
    g.move(20, 120);
    expect(g.up(), false);
    g.down(0, 0);
    g.move(9, 0);
    expect(g.up(), false);
  });
  test('cancel prevents late timer from entering video', () {
    final g = GestureMachine()
      ..down(0, 0)
      ..cancel();
    expect(g.hold(), false);
  });
}
