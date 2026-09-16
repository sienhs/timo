import 'dart:math' as math;
import 'dart:ui';

/// Normalized framing shared by the editor and the saved image renderer.
class PhotoFraming {
  const PhotoFraming({
    this.contain = false,
    this.scale = 1,
    this.x = 0,
    this.y = 0,
  });

  final bool contain;
  final double scale, x, y;
  static const matte = Color(0xFF0B0F1A);

  PhotoFraming copyWith({double? scale, double? x, double? y}) => PhotoFraming(
    contain: contain,
    scale: (scale ?? this.scale).clamp(1, 3),
    x: (x ?? this.x).clamp(-1, 1),
    y: (y ?? this.y).clamp(-1, 1),
  );

  Rect destination(Size image, Size frame) {
    final sx = frame.width / image.width, sy = frame.height / image.height;
    final factor = contain ? math.min(sx, sy) : math.max(sx, sy) * scale;
    final width = image.width * factor, height = image.height * factor;
    return Rect.fromLTWH(
      (frame.width - width) * (contain ? 0.5 : (x + 1) / 2),
      (frame.height - height) * (contain ? 0.5 : (y + 1) / 2),
      width,
      height,
    );
  }

  void paint(Canvas canvas, Image image, Size frame) {
    canvas.save();
    canvas.clipRect(Offset.zero & frame);
    canvas.drawColor(matte, BlendMode.src);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(
      image,
      Offset.zero & size,
      destination(size, frame),
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  Map<String, dynamic> toJson() => {
    'contain': contain,
    'scale': scale,
    'x': x,
    'y': y,
  };
  factory PhotoFraming.fromJson(Map<String, dynamic> json) => PhotoFraming(
    contain: json['contain'] == true,
    scale: ((json['scale'] as num?)?.toDouble() ?? 1).clamp(1, 3),
    x: ((json['x'] as num?)?.toDouble() ?? 0).clamp(-1, 1),
    y: ((json['y'] as num?)?.toDouble() ?? 0).clamp(-1, 1),
  );
}
