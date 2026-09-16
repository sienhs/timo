import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';
import '../../data/gesture_machine.dart';
import '../../data/immersive_session.dart';
import '../../screens/immersive_video_screen.dart';

/// Wraps the ticket photo with the hold/drag/flip gesture. Holding gathers
/// light into the finger, then the video takes over the whole screen in an
/// overlay ([ImmersiveVideoPage]). Releasing lets the pass finish;
/// the page then shrinks back onto the card.
class ImmersiveVideo extends StatefulWidget {
  const ImmersiveVideo({
    super.key,
    required this.photo,
    required this.videoUrl,
    required this.transition,
    required this.onDrag,
    required this.onFlip,
  });
  final Widget photo;
  final String videoUrl;
  final Map<String, dynamic> transition;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onFlip;
  @override
  State<ImmersiveVideo> createState() => _ImmersiveVideoState();
}

class _ImmersiveVideoState extends State<ImmersiveVideo>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// Light gathers under the finger during the hold, then bursts on entry.
  late final AnimationController gather = AnimationController(
    vsync: this,
    duration: ImmersiveConstants.hold,
    reverseDuration: Motion.fast,
  );
  late final AnimationController burst = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  final gesture = GestureMachine();
  VideoPlayerController? video;
  ImmersiveSession? session;

  /// Fullscreen page lives in the root overlay, not a route: pushing a route
  /// would cancel the finger that is still holding the card.
  OverlayEntry? page;
  Timer? timer;
  bool ready = false, failed = false, closed = false;
  int? pointer;
  Offset pressPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    preload();
  }

  Future<void> preload() async {
    final controller = widget.videoUrl.startsWith('assets/')
        ? VideoPlayerController.asset(widget.videoUrl)
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    video = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (closed) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      controller.addListener(onVideoTick);
      if (!mounted) return;
      setState(() => ready = true);
      session?.markReady();
      if (session?.phase == ImmersivePhase.held) await controller.play();
    } catch (_) {
      if (mounted) setState(() => failed = true);
      session?.markFailed();
    }
  }

  Rect cardRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Hold completed: burst, then take the whole screen.
  Future<void> enter() async {
    if (!gesture.hold() || session != null) return;
    HapticFeedback.lightImpact();
    burst.forward(from: 0);
    gather.reverse();
    final current = ImmersiveSession(
      controller: video,
      ready: ready,
      failed: failed,
      transition: widget.transition,
    );
    session = current;
    final origin = cardRect();
    final entry = OverlayEntry(
      builder: (_) => ImmersiveVideoPage(
        session: current,
        origin: origin,
        onClosed: () => onPageClosed(current),
      ),
    );
    page = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    if (ready) {
      try {
        // Held: loop. Released later: the current pass finishes, then exits.
        await video?.setLooping(true);
        await video?.play();
      } catch (_) {
        if (mounted) setState(() => failed = true);
        current.markFailed();
      }
    }
  }

  /// Finger lifted during playback: let this pass of the video finish.
  void release() {
    timer?.cancel();
    gather.reverse();
    final current = session;
    if (current == null) return;
    if (!current.playable) {
      current.close();
      return;
    }
    current.release();
    unawaited(video?.setLooping(false));
  }

  /// Video tick while lingering: exit gracefully on completion.
  void onVideoTick() {
    final current = session;
    final value = video?.value;
    if (current == null || value == null) return;
    if (current.phase != ImmersivePhase.lingering) return;
    final ended =
        value.isCompleted ||
        (value.duration > Duration.zero && value.position >= value.duration);
    if (ended) {
      current.close(graceful: true);
    }
  }

  /// Immediate exit for cancels: drag, lifecycle, no playable video.
  void leave() {
    timer?.cancel();
    gather.reverse();
    session?.close();
    final controller = video;
    if (ready && controller != null) unawaited(controller.pause());
  }

  void onPageClosed(ImmersiveSession current) {
    if (identical(session, current)) {
      session = null;
      page?.remove();
      page = null;
    }
    final controller = video;
    if (ready && controller != null) unawaited(pauseAndReset(controller));
  }

  Future<void> pauseAndReset(VideoPlayerController controller) async {
    try {
      await controller.pause();
      if (!closed) await controller.seekTo(Duration.zero);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hiding the system bars for fullscreen makes Android report a brief
    // `inactive`; only a real background transition should stop the video.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      gesture.cancel();
      pointer = null;
      leave();
    }
  }

  @override
  void dispose() {
    closed = true;
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    page?.remove();
    page = null;
    video?.removeListener(onVideoTick);
    video?.dispose();
    gather.dispose();
    burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '메모리 티켓. 좌우로 밀면 뒤집기. 길게 누르면 전체 화면 영상.',
    customSemanticsActions: {
      const CustomSemanticsAction(label: '티켓 뒤집기'): widget.onFlip,
    },
    child: Listener(
      onPointerDown: (event) {
        if (pointer != null) return;
        pointer = event.pointer;
        pressPoint = event.localPosition;
        gesture.down(event.localPosition.dx, event.localPosition.dy);
        gather.forward(from: 0);
        timer = Timer(ImmersiveConstants.hold, enter);
      },
      onPointerMove: (event) {
        if (pointer != event.pointer) return;
        final exit = gesture.move(
          event.localPosition.dx,
          event.localPosition.dy,
        );
        if (gesture.mode == GestureMode.dragging) {
          timer?.cancel();
          gather.reverse();
          if (exit) leave();
          widget.onDrag(Offset(gesture.delta.x, gesture.delta.y));
        }
      },
      onPointerUp: (event) {
        if (pointer != event.pointer) return;
        pointer = null;
        final wasImmersive = gesture.mode == GestureMode.immersive;
        final flip = gesture.up();
        if (wasImmersive) {
          release();
        } else {
          timer?.cancel();
          gather.reverse();
        }
        widget.onDrag(Offset.zero);
        if (flip) widget.onFlip();
      },
      onPointerCancel: (event) {
        if (pointer != event.pointer) return;
        pointer = null;
        gesture.cancel();
        leave();
        widget.onDrag(Offset.zero);
      },
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // The photo carries the 3D flip transform; never clip it here.
          widget.photo,
          AnimatedBuilder(
            animation: Listenable.merge([gather, burst]),
            builder: (_, _) => gather.value > 0 || burst.isAnimating
                ? Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GatherLightPainter(
                          center: pressPoint,
                          progress: gather.value,
                          burst: burst.isAnimating ? burst.value : null,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

/// Light gathers toward the finger while holding (sparks spiral inward,
/// a core glow builds), then on entry the gathered light floods outward as
/// the fullscreen video grows out of the card. Sparks are index-hashed:
/// no per-frame allocation beyond paints.
class _GatherLightPainter extends CustomPainter {
  _GatherLightPainter({
    required this.center,
    required this.progress,
    required this.burst,
  });
  final Offset center;
  final double progress;
  final double? burst;
  static const _sparks = 26;
  static const _radius = 120.0;
  static const _goldenAngle = 2.399963;

  static double _hash(int i, double seed) =>
      ((math.sin(i * 12.9898 + seed) * 43758.5453) % 1).abs();

  @override
  void paint(Canvas canvas, Size size) {
    final seed = center.dx * 0.013 + center.dy * 0.007;
    final light = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..blendMode = BlendMode.plus;
    if (progress > 0) {
      final p = Curves.easeInQuad.transform(progress);
      final glow = Curves.easeInSine.transform(progress);
      for (var i = 0; i < _sparks; i++) {
        final h = _hash(i, seed), h2 = _hash(i + 100, seed);
        final angle0 = i * _goldenAngle + h * 0.6;
        final r0 = _radius * (0.55 + 0.45 * h2);
        Offset at(double t) {
          final a = angle0 + t * 1.8;
          return center + Offset(math.cos(a), math.sin(a)) * (r0 * (1 - t));
        }

        final head = at(p);
        final tail = at((p - 0.08).clamp(0.0, 1.0));
        final alpha = (0.5 + 0.5 * p) * (0.7 + 0.3 * h);
        light
          ..color = TimoColors.accentSoft.withValues(alpha: alpha * 0.55)
          ..strokeWidth = 1.8 + 1.8 * p;
        canvas.drawLine(tail, head, light);
        dot.color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(head, 1.8 + 2.2 * p, dot);
      }
      final r = 12 + 40 * glow;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9 * glow),
              TimoColors.accent.withValues(alpha: 0.55 * glow),
              TimoColors.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    final b = burst;
    if (b != null) {
      final fade = 1 - Curves.easeOutQuart.transform(b);
      final spread = Curves.easeOutCubic.transform(b);
      final flashRadius = 40 + size.longestSide * 1.1 * spread;
      canvas.drawCircle(
        center,
        flashRadius,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.85 * fade),
              TimoColors.accent.withValues(alpha: 0.35 * fade),
              Colors.transparent,
            ],
            stops: const [0, 0.4, 1],
          ).createShader(Rect.fromCircle(center: center, radius: flashRadius)),
      );
      canvas.drawCircle(
        center,
        30 + 160 * spread,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + 5 * fade
          ..color = TimoColors.accentSoft.withValues(alpha: 0.7 * fade),
      );
      dot.color = Colors.white.withValues(alpha: 0.7 * fade);
      for (var i = 0; i < _sparks; i++) {
        final angle = i * _goldenAngle + b * 0.8;
        final pos =
            center +
            Offset(math.cos(angle), math.sin(angle)) *
                (30 + (150 + 80 * _hash(i, seed)) * spread);
        canvas.drawCircle(pos, 1.5 + 1.5 * fade, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_GatherLightPainter old) =>
      old.progress != progress || old.burst != burst || old.center != center;
}
