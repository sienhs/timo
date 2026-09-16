import 'package:flutter/widgets.dart';

/// Named motion values shared by every domain. anime.js-style: expressive
/// exponential ease-outs for entrances, springs for physical objects.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 620);
  static const entrance = Duration(milliseconds: 760);
  static const stagger = Duration(milliseconds: 70);

  /// Exponential ease-out: fast start, long soft landing.
  static const emphasized = Curves.easeOutExpo;
  static const standard = Curves.easeOutCubic;
  static const overshoot = Curves.easeOutBack;
  static const enterExit = Curves.easeInOutCubic;

  /// Card tilt spring: light mass, a bit under-damped so releases wobble.
  static const tiltSpring = SpringDescription(
    mass: 1,
    stiffness: 170,
    damping: 15,
  );

  /// Press-feedback spring: snappy and settles quickly.
  static const pressSpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 24,
  );

  static const pressScale = 0.965;
  static const revealOffset = 22.0;

  /// True when the OS or a test asks for reduced motion. Ambient loops
  /// (aurora, particles, shimmer) render a static frame in that case.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
