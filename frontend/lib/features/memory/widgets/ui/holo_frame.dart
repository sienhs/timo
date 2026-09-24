import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../theme/timo_colors.dart';

/// 카드 안쪽에 한 번 들어간 홀로그램 하이라인 테두리.
///
/// 앞면(사진 가장자리)과 오르골 뒷면이 같은 선을 써서 한 장의 카드로 읽힌다.
/// 오르골에서 앞 카드와 뒤 카드가 같은 어두운 재질이라, 이 선이 겹치는
/// 경계를 가른다. 스택 안에서 `Positioned.fill` 로 덮는다.
class HoloFrame extends StatelessWidget {
  const HoloFrame({super.key, required this.inset, required this.radius});

  /// 카드 가장자리에서 선까지의 거리.
  final EdgeInsets inset;

  /// 선이 그리는 둥근 모서리.
  final double radius;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _HoloFramePainter(inset, radius)),
  );
}

class _HoloFramePainter extends CustomPainter {
  const _HoloFramePainter(this.inset, this.radius);
  final EdgeInsets inset;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = inset.deflateRect(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CollectionLayout.holoFrameStroke
        ..shader = TimoGradients.holo
            .scale(CollectionLayout.holoFrameOpacity)
            .createShader(frame),
    );
  }

  @override
  bool shouldRepaint(_HoloFramePainter old) =>
      old.inset != inset || old.radius != radius;
}
