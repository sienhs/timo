import 'dart:math' as math;
import 'dart:ui';

/// Independent bounds in fractions of the final 900 × 1400 ticket canvas.
class PersonPlacement {
  const PersonPlacement(this.rect);
  final Rect rect;
  static const canvasSize = Size(900, 1400);
  static const canvasAspect = 9 / 14;

  factory PersonPlacement.initial(Size image, int index) {
    final scale = math.min(
      0.58 * canvasSize.width / image.width,
      0.68 * canvasSize.height / image.height,
    );
    final size = Size(
      image.width * scale / canvasSize.width,
      image.height * scale / canvasSize.height,
    );
    return PersonPlacement(
      Rect.fromCenter(
        center: Offset(index == 0 ? 0.5 : 0.65, 0.53),
        width: size.width,
        height: size.height,
      ),
    ).move(Offset.zero);
  }

  factory PersonPlacement.fromPerson(Map<String, dynamic> person) {
    final p = person['placement'] as Map;
    return PersonPlacement(
      Rect.fromLTWH(
        (p['left'] as num).toDouble(),
        (p['top'] as num).toDouble(),
        (p['width'] as num).toDouble(),
        (p['height'] as num).toDouble(),
      ),
    );
  }

  Map<String, double> toJson() => {
    'left': rect.left,
    'top': rect.top,
    'width': rect.width,
    'height': rect.height,
  };

  Rect inCanvas(Size size) => Rect.fromLTWH(
    rect.left * size.width,
    rect.top * size.height,
    rect.width * size.width,
    rect.height * size.height,
  );

  PersonPlacement move(Offset delta) => PersonPlacement(
    Rect.fromLTWH(
      (rect.left + delta.dx).clamp(0, math.max(0, 1 - rect.width)),
      (rect.top + delta.dy).clamp(0, math.max(0, 1 - rect.height)),
      rect.width,
      rect.height,
    ),
  );

  /// Resize from a corner, preserving aspect and holding its opposite fixed.
  PersonPlacement resize(Offset delta, Offset corner, Size canvas) {
    final anchor = Offset(
      corner.dx > 0 ? rect.left : rect.right,
      corner.dy > 0 ? rect.top : rect.bottom,
    );
    final w = rect.width * canvas.width, h = rect.height * canvas.height;
    final factor =
        1 +
        (delta.dx * corner.dx * w + delta.dy * corner.dy * h) / (w * w + h * h);
    final maxX = (corner.dx > 0 ? 1 - anchor.dx : anchor.dx) / rect.width;
    final maxY = (corner.dy > 0 ? 1 - anchor.dy : anchor.dy) / rect.height;
    final upper = math.min(maxX, maxY);
    final lower = math.min(upper, 0.08 / math.max(rect.width, rect.height));
    final scale = factor.clamp(lower, upper);
    final width = rect.width * scale, height = rect.height * scale;
    return PersonPlacement(
      Rect.fromLTWH(
        corner.dx > 0 ? anchor.dx : anchor.dx - width,
        corner.dy > 0 ? anchor.dy : anchor.dy - height,
        width,
        height,
      ),
    );
  }

  PersonPlacement scaleBy(double factor) {
    final upper = math.min(1 / rect.width, 1 / rect.height);
    final lower = 0.08 / math.max(rect.width, rect.height);
    final scale = factor.clamp(lower, upper);
    return PersonPlacement(
      Rect.fromCenter(
        center: rect.center,
        width: rect.width * scale,
        height: rect.height * scale,
      ),
    ).move(Offset.zero);
  }
}
