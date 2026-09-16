import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/motion/ambient_motion.dart';
import 'package:timo/features/memory/motion/staggered_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ambient = AmbientMotion.instance;
  void noop() {}
  ambient.addListener(noop);

  setUp(() {
    ambient.enabled = true;
    ambient.relaxEnergy();
    ambient.clearFocus();
    ambient.pressGlow(false);
    for (var i = 0; i < 200; i++) {
      ambient.step(1 / 60);
    }
  });

  test('channels ease toward targets and a pulse decays by itself', () {
    expect(ambient.energy, closeTo(AmbientMotion.restEnergy, 0.01));
    ambient.calm(true);
    ambient.pressGlow(true);
    ambient.focusOn(const Offset(0.2, 0.3));
    ambient.pulse();
    expect(ambient.burst, 1);
    ambient.step(1 / 60);
    expect(ambient.energy, lessThan(AmbientMotion.restEnergy));
    expect(ambient.glow, greaterThan(0));
    for (var i = 0; i < 240; i++) {
      ambient.step(1 / 60);
    }
    expect(ambient.energy, closeTo(AmbientMotion.calmEnergy, 0.01));
    expect(ambient.glow, closeTo(1, 0.01));
    expect(ambient.focusStrength, closeTo(1, 0.01));
    expect(ambient.focus.dx, closeTo(0.2, 0.01));
    expect(ambient.burst, 0);
  });

  test('setEnergy is immediate and clamped; disabled ignores writes', () {
    ambient.setEnergy(3);
    expect(ambient.energy, 1);
    ambient.enabled = false;
    ambient.setEnergy(0);
    ambient.pulse();
    expect(ambient.energy, 1);
    expect(ambient.burst, 0);
    ambient.enabled = true;
  });

  test('staggered text splits into lines of words', () {
    expect(StaggeredText.words('그날의 순간을,\n다시 꺼내보세요.'), [
      ['그날의', '순간을,'],
      ['다시', '꺼내보세요.'],
    ]);
  });
}
