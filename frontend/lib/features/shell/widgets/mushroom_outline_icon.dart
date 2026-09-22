import 'package:flutter/material.dart';

/// 빠른 메뉴의 Material 아이콘과 같은 크기·선 굵기로 그린 버섯 윤곽.
class MushroomOutlineIcon extends StatelessWidget {
  const MushroomOutlineIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MushroomOutlinePainter(color)),
  );
}

class _MushroomOutlinePainter extends CustomPainter {
  const _MushroomOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cap = Path()
      ..moveTo(2.7, 12.1)
      ..cubicTo(2.7, 7.1, 6.8, 3.2, 12, 3.2)
      ..cubicTo(17.2, 3.2, 21.3, 7.1, 21.3, 12.1)
      ..cubicTo(21.3, 13.7, 20.5, 14.5, 19.2, 14.5)
      ..cubicTo(16.8, 13.2, 14.5, 12.5, 12, 12.5)
      ..cubicTo(9.5, 12.5, 7.2, 13.2, 4.8, 14.5)
      ..cubicTo(3.5, 14.5, 2.7, 13.7, 2.7, 12.1);
    canvas.drawPath(cap, paint);

    final stem = Path()
      ..moveTo(9.5, 12.9)
      ..cubicTo(9.4, 16.0, 9.0, 18.2, 8.6, 19.5)
      ..cubicTo(8.2, 21.5, 9.8, 22.3, 12, 22.3)
      ..cubicTo(14.2, 22.3, 15.8, 21.5, 15.4, 19.5)
      ..cubicTo(15.0, 18.2, 14.6, 16.0, 14.5, 12.9);
    canvas.drawPath(stem, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MushroomOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}
