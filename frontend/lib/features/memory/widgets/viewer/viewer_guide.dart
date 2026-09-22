import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';
import '../ui/glass_panel.dart';
import '../ui/glow_button.dart';

/// 소장품 화면의 조작법 안내를 띄운다. 닫히면 끝난다.
///
/// 처음 열 때 한 번 뜨고, 앱바의 ? 로 다시 볼 수 있다. 화면에 늘 적어 두던
/// "좌우로 밀어 뒤집기 · 길게 눌러 영상 보기" 를 대신한다 — 글로 적어 둔
/// 조작법은 두 번째부터 읽지 않고, 카드 아래 자리만 차지했다.
Future<void> showViewerGuide(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: ViewerText.guideOk,
  barrierColor: const Color(0xD9070A12),
  transitionDuration: Motion.base,
  pageBuilder: (_, _, _) => const ViewerGuide(),
  transitionBuilder: (context, animation, _, child) {
    final curve = CurvedAnimation(parent: animation, curve: Motion.emphasized);
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(curve),
        child: child,
      ),
    );
  },
);

/// 안내 본문. 손짓 두 개가 실제로 움직여 보인다 — 글만 읽고 따라 하기보다
/// 한 번 보는 쪽이 빠르다. 동작 줄이기 설정이면 멈춘 그림으로 둔다.
class ViewerGuide extends StatelessWidget {
  const ViewerGuide({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          type: MaterialType.transparency,
          child: GlassPanel(
            color: TimoColors.glassStrong,
            glow: TimoColors.accent,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  ViewerText.guideTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: TimoColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 22),
                const _GuideRow(
                  demo: _SwipeDemo(),
                  title: ViewerText.guideSwipe,
                  body: ViewerText.guideSwipeBody,
                ),
                const SizedBox(height: 18),
                const _GuideRow(
                  demo: _HoldDemo(),
                  title: ViewerText.guideHold,
                  body: ViewerText.guideHoldBody,
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: ViewerText.guideOk,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.demo,
    required this.title,
    required this.body,
  });
  final Widget demo;
  final String title, body;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 84, height: 84, child: demo),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: TimoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: TimoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 한 방향으로 반복되는 손짓의 시간축. 동작 줄이기면 중간에 멈춰 선다.
class _Loop extends StatefulWidget {
  const _Loop({required this.duration, required this.builder});
  final Duration duration;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      controller.stop();
      controller.value = 0.5;
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => widget.builder(context, controller.value),
  );
}

/// 작은 카드가 손을 따라 옆으로 밀리며 뒤집힌다.
class _SwipeDemo extends StatelessWidget {
  const _SwipeDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    duration: const Duration(milliseconds: 1800),
    builder: (context, t) {
      // 0→1: 손이 왼쪽에서 오른쪽으로, 카드는 그만큼 돌아간다. 마지막 1/4 은
      // 멈춰 서서 한 번 밀었다는 것이 읽히게 한다.
      final sweep = Curves.easeInOutCubic.transform((t / 0.75).clamp(0.0, 1.0));
      final angle = sweep * math.pi;
      final showsBack = angle > math.pi / 2;
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0022)
              ..rotateY(angle),
            child: Container(
              width: 40,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                gradient: showsBack
                    ? const LinearGradient(
                        colors: [Color(0xFF141B2E), Color(0xFF0A0E1A)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [TimoColors.violet, TimoColors.cyan],
                      ),
                border: Border.all(color: TimoColors.glassBorder),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(-22 + sweep * 44, 20),
            child: const Icon(
              Icons.touch_app_rounded,
              size: 26,
              color: TimoColors.accent,
            ),
          ),
        ],
      );
    },
  );
}

/// 손이 눌러 누르고 있으면 둥근 파문이 퍼지고 재생 표시가 떠오른다.
class _HoldDemo extends StatelessWidget {
  const _HoldDemo();

  @override
  Widget build(BuildContext context) => _Loop(
    duration: const Duration(milliseconds: 1600),
    builder: (context, t) {
      final ring = Curves.easeOut.transform(t);
      final play = Curves.easeInOut.transform(((t - 0.35) / 0.4).clamp(0, 1));
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 24 + ring * 44,
            height: 24 + ring * 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TimoColors.accent.withValues(alpha: 1 - ring),
                width: 2,
              ),
            ),
          ),
          Opacity(
            opacity: play,
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                size: 22,
                color: TimoColors.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.touch_app_rounded,
            size: 26,
            color: TimoColors.accent,
          ),
        ],
      );
    },
  );
}
