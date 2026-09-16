import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../theme/timo_colors.dart';
import '../constants.dart';
import '../data/immersive_session.dart';

/// Fullscreen playback, inserted into the root [Overlay] by the card. Grows
/// from the card's on-screen rectangle to the whole display over a near-black
/// scrim, hides the system bars, and shrinks back when the session closes.
class ImmersiveVideoPage extends StatefulWidget {
  const ImmersiveVideoPage({
    super.key,
    required this.session,
    required this.origin,
    required this.onClosed,
  });
  final ImmersiveSession session;

  /// Card rectangle in global coordinates the video expands from.
  final Rect origin;
  final VoidCallback onClosed;

  @override
  State<ImmersiveVideoPage> createState() => _ImmersiveVideoPageState();
}

class _ImmersiveVideoPageState extends State<ImmersiveVideoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController expand = AnimationController(
    vsync: this,
    duration: ImmersiveConstants.enter,
    reverseDuration: ImmersiveConstants.leave,
  );
  bool finished = false;
  Timer? popTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.session.addListener(onSession);
    widget.session.controller?.addListener(onVideo);
    expand.forward();
    onSession();
  }

  void onSession() {
    if (!mounted) return;
    if (widget.session.phase == ImmersivePhase.closing) {
      final duration = widget.session.graceful
          ? ImmersiveConstants.enter
          : ImmersiveConstants.leave;
      expand.animateBack(0, duration: duration);
      popTimer?.cancel();
      popTimer = Timer(duration + const Duration(milliseconds: 40), finish);
    } else {
      setState(() {});
    }
  }

  void onVideo() {
    if (mounted && widget.session.phase == ImmersivePhase.lingering) {
      setState(() {});
    }
  }

  /// Animation done: hand control back to the card, which removes us.
  void finish() {
    if (finished) return;
    finished = true;
    widget.onClosed();
  }

  @override
  void dispose() {
    popTimer?.cancel();
    widget.session.removeListener(onSession);
    widget.session.controller?.removeListener(onVideo);
    expand.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  List<double> colorMatrix() {
    final transition = widget.session.transition;
    final saturation = (transition['saturation'] as num?)?.toDouble() ?? 1;
    final contrast = (transition['contrast'] as num?)?.toDouble() ?? 1;
    final brightness =
        ((transition['brightness'] as num?)?.toDouble() ?? 0) * 255 +
        128 * (1 - contrast);
    final r = (1 - saturation) * 0.2126,
        g = (1 - saturation) * 0.7152,
        b = (1 - saturation) * 0.0722;
    return [
      (r + saturation) * contrast,
      g * contrast,
      b * contrast,
      0,
      brightness,
      r * contrast,
      (g + saturation) * contrast,
      b * contrast,
      0,
      brightness,
      r * contrast,
      g * contrast,
      (b + saturation) * contrast,
      0,
      brightness,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    final session = widget.session;
    final controller = session.controller;
    return AnimatedBuilder(
      animation: expand,
      builder: (_, _) {
        final t = Curves.easeInOutCubic.transform(expand.value);
        final rect = Rect.lerp(widget.origin, screen, t)!;
        final radius = (TimoRadii.card * (1 - t)).clamp(0.0, TimoRadii.card);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // A tap after release dismisses early.
          onTap: session.phase == ImmersivePhase.lingering
              ? () => session.close()
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(
                  alpha: ImmersiveConstants.scrimOpacity * t,
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (session.playable)
                          ColorFiltered(
                            colorFilter: ColorFilter.matrix(colorMatrix()),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: controller!.value.size.width,
                                height: controller.value.size.height,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          )
                        else
                          const _VideoUnavailable(),
                        if (session.phase == ImmersivePhase.lingering &&
                            session.playable)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: ImmersiveConstants.lingerBarHeight,
                            child: _LingerProgress(value: controller!.value),
                          ),
                        // Soft rim so the frame reads as glowing while it grows.
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(radius),
                              border: Border.all(
                                color: TimoColors.accent.withValues(
                                  alpha: 0.6 * math.sin(t * math.pi),
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Remaining-time cue while the released video plays out.
class _LingerProgress extends StatelessWidget {
  const _LingerProgress({required this.value});
  final VideoPlayerValue value;
  @override
  Widget build(BuildContext context) {
    final total = value.duration.inMilliseconds;
    final progress = total == 0
        ? 0.0
        : (value.position.inMilliseconds / total).clamp(0.0, 1.0);
    return Semantics(
      label: '영상 재생 진행률',
      value: '${(progress * 100).round()}%',
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [TimoColors.cyan, TimoColors.accent],
              ),
              boxShadow: [BoxShadow(color: Color(0x884ADE80), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoUnavailable extends StatelessWidget {
  const _VideoUnavailable();
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF18243E), Color(0xFF0B1020)],
      ),
    ),
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.movie_filter_outlined,
          color: TimoColors.textSecondary.withValues(alpha: 0.8),
          size: 34,
        ),
        const SizedBox(height: 10),
        const Text(
          '공식 영상 준비 중',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
