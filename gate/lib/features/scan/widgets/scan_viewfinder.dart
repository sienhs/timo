import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 카메라 위에 올리는 덮개. 조준 틀 안만 카메라가 보이고 나머지는 반투명
/// 검정으로 덮는다. 틀에는 모서리를 따라 굽은 브랜드색 꺾쇠 넷과, 위아래로
/// 오가며 빛이 번지는 스캔 선을 그린다.
///
/// [child] 는 틀 아래에 놓이는 안내다. 틀의 위치를 아는 곳이 여기뿐이라
/// 안내도 여기서 자리를 잡아 준다.
///
/// 인식 영역을 제한하지는 않는다(카메라 전체에서 읽는다). 덮개는 관람객이 폰을
/// 어디에 대야 할지 알려 주는 안내일 뿐이다. 실제로 영역을 좁히면 폰을 조금
/// 비켜 든 사람이 계속 인식되지 않아 줄이 느려진다.
///
/// 스캔 선은 "지금 읽고 있다" 는 신호다. 기기의 '동작 줄이기' 설정이 켜져
/// 있으면 멈춘 채 가운데에 둔다.
class ScanViewfinder extends StatefulWidget {
  const ScanViewfinder({super.key, required this.child});

  final Widget child;

  @override
  State<ScanViewfinder> createState() => _ScanViewfinderState();
}

class _ScanViewfinderState extends State<ScanViewfinder>
    with SingleTickerProviderStateMixin {
  late final _sweep = AnimationController(
    vsync: this,
    duration: ScanMetrics.scanLineSweep,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep
        ..stop()
        ..value = 0.5;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth * ScanMetrics.viewfinderFraction;
        final window = Rect.fromLTWH(
          (constraints.maxWidth - side) / 2,
          constraints.maxHeight * ScanMetrics.viewfinderTopFraction,
          side,
          side,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _sweep,
              builder: (context, _) => CustomPaint(
                painter: _ViewfinderPainter(
                  window: window,
                  lineOffset: Curves.easeInOut.transform(_sweep.value),
                ),
              ),
            ),
            Positioned(
              top: window.bottom + ScanMetrics.viewfinderToGuideGap,
              left: 0,
              right: 0,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.window, required this.lineOffset});

  /// 카메라가 보이는 구멍.
  final Rect window;

  /// 스캔 선의 세로 위치. 0 이 구멍 맨 위, 1 이 맨 아래.
  final double lineOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(ScanMetrics.viewfinderRadius);
    final hole = RRect.fromRectAndRadius(window, radius);

    // 구멍을 뺀 나머지를 반투명 검정으로 덮는다.
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(scrim, Paint()..color = AppColors.scanScrim);

    _paintScanLine(canvas, hole);
    _paintCorners(canvas, radius.x);
  }

  /// 스캔 선. 가운데 밝은 선 하나와 위아래로 옅게 번지는 브랜드색 빛.
  /// 구멍 안에서만 그린다 — 밖으로 새면 덮개가 뚫린 것처럼 보인다.
  void _paintScanLine(Canvas canvas, RRect hole) {
    final y = window.top + window.height * lineOffset;
    canvas
      ..save()
      ..clipRRect(hole);

    final glowRect = Rect.fromLTRB(
      window.left,
      y - ScanMetrics.scanLineGlow,
      window.right,
      y + ScanMetrics.scanLineGlow,
    );
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0),
            AppColors.primary.withValues(alpha: 0.35),
            AppColors.primary.withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );
    canvas.drawLine(
      Offset(window.left, y),
      Offset(window.right, y),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = ScanMetrics.scanLineStroke,
    );
    canvas.restore();
  }

  /// 네 귀퉁이 꺾쇠. 구멍의 둥근 모서리를 따라 굽는다. 변 전체를 그리지 않아
  /// 구멍 경계가 답답해 보이지 않는다.
  void _paintCorners(Canvas canvas, double radius) {
    final corner = Paint()
      ..color = AppColors.primary
      ..strokeWidth = ScanMetrics.viewfinderStroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // 곡선 뒤에 남는 직선 길이.
    final straight = ScanMetrics.viewfinderCornerLength - radius;
    final l = window.left;
    final t = window.top;
    final r = window.right;
    final b = window.bottom;

    final path = Path()
      // 왼쪽 위
      ..moveTo(l, t + radius + straight)
      ..lineTo(l, t + radius)
      ..arcToPoint(Offset(l + radius, t), radius: Radius.circular(radius))
      ..lineTo(l + radius + straight, t)
      // 오른쪽 위
      ..moveTo(r - radius - straight, t)
      ..lineTo(r - radius, t)
      ..arcToPoint(Offset(r, t + radius), radius: Radius.circular(radius))
      ..lineTo(r, t + radius + straight)
      // 오른쪽 아래
      ..moveTo(r, b - radius - straight)
      ..lineTo(r, b - radius)
      ..arcToPoint(Offset(r - radius, b), radius: Radius.circular(radius))
      ..lineTo(r - radius - straight, b)
      // 왼쪽 아래
      ..moveTo(l + radius + straight, b)
      ..lineTo(l + radius, b)
      ..arcToPoint(Offset(l, b - radius), radius: Radius.circular(radius))
      ..lineTo(l, b - radius - straight);
    canvas.drawPath(path, corner);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.lineOffset != lineOffset || oldDelegate.window != window;
}
