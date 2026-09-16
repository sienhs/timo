import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../effects/effect_quality.dart';
import '../../motion/motion_tokens.dart';
import '../../models/memory_ticket.dart';
import '../../models/person_depth_layer.dart';
import '../../models/ticket_effect.dart';
import '../../theme/timo_colors.dart';
import '../ui/gradient_text.dart';
import '../ui/local_image.dart';
import '../../constants.dart';
import '../../effects/stage_effects.dart';
import '../../effects/volumetric_light.dart';
import 'depth_photo.dart';
import 'person_depth_photo.dart';
import 'effect_layer.dart';
import 'holo_overlay.dart';
import 'person_rim_light.dart';
import 'ticket_back.dart';

typedef InteractionWrapper = Widget Function(
  Widget photo,
  ValueChanged<Offset> onDrag,
  VoidCallback onFlip,
);

/// The 3D memory ticket. Tilt is a damped spring driven by device tilt
/// (accelerometer + gyro) and by drag, and
/// published through [ValueNotifier]s, so per-frame work is paint-only: the
/// front and back faces are built once and their painters listen for tilt.
class MemoryTicketCard extends StatefulWidget {
  const MemoryTicketCard({
    super.key,
    required this.ticket,
    required this.wrap,
    this.glow = TimoColors.accent,
  });
  final MemoryTicket ticket;
  final InteractionWrapper wrap;

  /// Colour of the soft glow under the card (the photo palette accent).
  final Color glow;
  @override
  State<MemoryTicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<MemoryTicketCard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController flip = AnimationController(
    vsync: this,
    duration: ViewerConstants.flipDuration,
  );
  late final Animation<double> flipCurve = CurvedAnimation(
    parent: flip,
    curve: Motion.overshoot,
    reverseCurve: Motion.overshoot.flipped,
  );
  late final AnimationController entrance = AnimationController(
    vsync: this,
    duration: Motion.entrance,
  );
  late final Ticker ticker = createTicker(tick);
  final tilt = ValueNotifier<Offset>(Offset.zero);
  final time = ValueNotifier<double>(0);
  final lift = ValueNotifier<double>(0);
  late Widget frontFace = _FrontFace(
    ticket: widget.ticket,
    tilt: tilt,
    time: time,
  );
  late final Widget backFace = TicketBack(
    ticket: widget.ticket,
    tilt: tilt,
    time: time,
  );
  StreamSubscription<GyroscopeEvent>? sensor;
  StreamSubscription<AccelerometerEvent>? accelSensor;
  Offset gravity = Offset.zero, gravityRest = Offset.zero;
  Offset accelTilt = Offset.zero;
  bool gravityInit = false;
  Offset velocity = Offset.zero, dragTarget = Offset.zero, gyro = Offset.zero;
  Duration last = Duration.zero;
  bool dragging = false, back = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ticker.start();
    startSensor();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      entrance.value = 1;
    } else if (!entrance.isAnimating && entrance.value == 0) {
      entrance.forward();
    }
  }

  void startSensor() {
    sensor?.cancel();
    accelSensor?.cancel();
    // Gyro: quick response to rotation, decays on its own.
    sensor = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval)
        .listen(
          (e) => gyro = clampTilt(
            Offset(
              gyro.dx * 0.9 + e.y * ViewerConstants.gyroGain,
              gyro.dy * 0.9 + e.x * ViewerConstants.gyroGain,
            ),
          ),
          onError: (_) {
            /* Touch remains available. */
          },
        );
    // Gravity: absolute device tilt. A slow baseline lets the card rest in
    // any pose and respond only to movement away from it, so it never drifts.
    accelSensor =
        accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
            .listen(
              (e) {
                final g = Offset(e.x, e.y);
                if (!gravityInit) {
                  gravity = g;
                  gravityRest = g;
                  gravityInit = true;
                  return;
                }
                gravity = Offset.lerp(
                  gravity,
                  g,
                  ViewerConstants.gravitySmoothing,
                )!;
                gravityRest = Offset.lerp(
                  gravityRest,
                  gravity,
                  ViewerConstants.gravityRestSmoothing,
                )!;
                final d = gravity - gravityRest;
                accelTilt = clampTilt(
                  Offset(
                    d.dx * ViewerConstants.gravityGain,
                    -d.dy * ViewerConstants.gravityGain,
                  ),
                );
              },
              onError: (_) {
                /* Touch remains available. */
              },
            );
  }

  @override
  void didUpdateWidget(MemoryTicketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticket != widget.ticket) {
      frontFace = _FrontFace(ticket: widget.ticket, tilt: tilt, time: time);
    }
  }

  static Offset clampTilt(Offset value) => Offset(
    value.dx.clamp(-ViewerConstants.maxTilt, ViewerConstants.maxTilt),
    value.dy.clamp(-ViewerConstants.maxTilt, ViewerConstants.maxTilt),
  );

  /// Spring integration toward drag + gyro target. Publishes to notifiers;
  /// nothing here rebuilds widgets.
  void tick(Duration elapsed) {
    final dt = ((elapsed - last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    last = elapsed;
    time.value = elapsed.inMicroseconds / 1e6;
    gyro = gyro * math.pow(ViewerConstants.gyroDecayPerSecond, dt).toDouble();
    final target = clampTilt(dragTarget + gyro + accelTilt);
    final spring = Motion.tiltSpring;
    final current = tilt.value;
    final acceleration =
        (target - current) * spring.stiffness - velocity * spring.damping;
    velocity += acceleration * dt;
    final next = current + velocity * dt;
    // Snap to rest so the tree stops repainting when idle.
    final settled =
        (next - target).distance < 0.005 && velocity.distance < 0.02;
    tilt.value = settled ? target : next;
    if (settled) velocity = Offset.zero;
    final liftTarget = dragging ? 1.0 : 0.0;
    final l = lift.value + (liftTarget - lift.value) * math.min(1, dt * 9);
    lift.value = (l - liftTarget).abs() < 0.002 ? liftTarget : l;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startSensor();
      if (!ticker.isActive) ticker.start();
    } else {
      sensor?.cancel();
      accelSensor?.cancel();
      ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sensor?.cancel();
    accelSensor?.cancel();
    ticker.dispose();
    flip.dispose();
    entrance.dispose();
    tilt.dispose();
    time.dispose();
    lift.dispose();
    super.dispose();
  }

  void drag(Offset value) {
    dragging = value != Offset.zero;
    dragTarget = clampTilt(value * ViewerConstants.dragGain);
  }

  void toggle() {
    back = !back;
    back ? flip.forward() : flip.reverse();
  }

  @override
  Widget build(BuildContext context) => widget.wrap(
    AnimatedBuilder(
      animation: Listenable.merge([flipCurve, entrance, tilt, lift]),
      builder: (_, _) {
        final t = tilt.value;
        final l = lift.value;
        final progress = flipCurve.value;
        final angle = progress * math.pi;
        final showBack = progress > 0.5;
        final enter = Motion.emphasized.transform(entrance.value);
        final radius = BorderRadius.circular(TimoRadii.card);
        final scale = (0.9 + 0.1 * enter) * (1 + ViewerConstants.liftScale * l);
        return Opacity(
          opacity: enter.clamp(0, 1),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, ViewerConstants.perspective)
              ..scaleByDouble(scale, scale, 1, 1)
              ..rotateX((1 - enter) * 0.35 - t.dy * ViewerConstants.tiltAngle)
              ..rotateY(angle + t.dx * ViewerConstants.tiltAngle),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // Dynamic shadow: slides opposite to the tilt and grows on lift.
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      -t.dx * 0.9,
                      ViewerConstants.shadowLift - t.dy * 0.6 + l * 12,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 40 + l * 14,
                            spreadRadius: -6,
                          ),
                          BoxShadow(
                            color: widget.glow.withValues(
                              alpha: 0.18 + l * 0.1,
                            ),
                            blurRadius: 70,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: radius,
                  child: showBack
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: backFace,
                        )
                      : frontFace,
                ),
              ],
            ),
          ),
        );
      },
    ),
    drag,
    toggle,
  );
}

/// Photo, person, effects and foil. Built once; children repaint via tilt.
class _FrontFace extends StatelessWidget {
  const _FrontFace({
    required this.ticket,
    required this.tilt,
    required this.time,
  });
  final MemoryTicket ticket;
  final ValueListenable<Offset> tilt;
  final ValueListenable<double> time;

  /// The volumetric light also touches the layers around the effect: far
  /// haze on the background and a rim on the person's lit contour.
  bool get volumetric => ticket.effect == TicketEffect.godRays;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (ticket.backgroundFraming?.contain == true)
        LocalImage(ticket.backgroundPath)
      else
        DepthPhoto(
          backgroundPath: ticket.backgroundPath,
          depthMapPath: ticket.depthMapPath,
          layers: ticket.depthLayers,
          tilt: tilt,
          preserveFraming: ticket.backgroundFraming != null,
          haze: volumetric ? VolumetricLightController.instance : null,
        ),
      // Haze, light cones and beams live between the stage and the person.
      EffectLayer(
        effect: ticket.effect,
        tilt: tilt,
        depth: EffectDepth.behind,
        parallax: ViewerConstants.behindEffectParallax,
      ),
      if (ticket.personCompositePath != null)
        _PersonLayer(
          path: ticket.personCompositePath!,
          exactLayout: ticket.manualPersonLayout,
          layers: ticket.personDepthLayers,
          tilt: tilt,
          rimLight: volumetric,
        ),
      // Only the nearest, sparse particles pass in front of the person.
      EffectLayer(
        effect: ticket.effect,
        tilt: tilt,
        depth: EffectDepth.front,
        parallax: ViewerConstants.frontEffectParallax,
      ),
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0x00000000), Color(0x73000000)],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
      ),
      HoloOverlay(
        tilt: tilt,
        time: time,
        idle: ViewerConstants.holoIdle,
        active: ViewerConstants.holoActive,
      ),
      const Positioned(left: 18, bottom: 16, child: _FrontBrand()),
      Positioned(
        right: 16,
        bottom: 14,
        child: ValueListenableBuilder<Offset>(
          valueListenable: tilt,
          builder: (_, t, _) =>
              _HoloSeal(angle: t.dx / ViewerConstants.maxTilt * 1.4),
        ),
      ),
    ],
  );
}

/// The person and its shadow stay anchored at the chosen position while the
/// background moves behind them. The whole card still tilts and flips.
class _PersonLayer extends StatelessWidget {
  const _PersonLayer({
    required this.path,
    required this.exactLayout,
    required this.layers,
    required this.tilt,
    this.rimLight = false,
  });
  final String path;
  final bool exactLayout;
  final List<PersonDepthLayer> layers;
  final ValueListenable<Offset> tilt;

  /// Add the volumetric rim light on the contour facing the fixture.
  final bool rimLight;
  @override
  Widget build(BuildContext context) {
    final image = Padding(
      padding: EdgeInsets.all(
        exactLayout ? 0 : ViewerConstants.foregroundInset,
      ),
      child: LocalImage(path),
    );
    final lowQuality =
        EffectQualityController.instance.value == EffectQuality.low;
    // Shadow silhouette: rendered once per frame inside its own boundary;
    // the blur is skipped on the low tier.
    Widget shadow = ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      child: image,
    );
    if (!lowQuality) {
      shadow = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: ViewerConstants.personShadowBlur,
          sigmaY: ViewerConstants.personShadowBlur,
        ),
        child: shadow,
      );
    }
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: ViewerConstants.personShadowOffset,
            child: Opacity(
              opacity: ViewerConstants.personShadowOpacity,
              child: RepaintBoundary(child: shadow),
            ),
          ),
          Transform.scale(
            scale: exactLayout ? 1 : ViewerConstants.personScale,
            alignment: Alignment.center,
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (layers.isEmpty)
                    image
                  else
                    PersonDepthStack(layers: layers, tilt: tilt),
                  // The rim samples the composite's alpha, laid out exactly
                  // like the drawn person (inset only for the plain image).
                  if (rimLight)
                    Padding(
                      padding: EdgeInsets.all(
                        exactLayout || layers.isNotEmpty
                            ? 0
                            : ViewerConstants.foregroundInset,
                      ),
                      child: PersonRimLight(path: path),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrontBrand extends StatelessWidget {
  const _FrontBrand();
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GradientText(
          'TIMO',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        Text(
          'MEMORY TICKET',
          style: TextStyle(
            fontSize: 8.5,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    ),
  );
}

/// Small iridescent seal whose gradient rotates with the tilt.
class _HoloSeal extends StatelessWidget {
  const _HoloSeal({required this.angle});
  final double angle;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          transform: GradientRotation(angle),
          colors: const [
            TimoColors.cyan,
            TimoColors.accent,
            TimoColors.gold,
            TimoColors.magenta,
            TimoColors.violet,
            TimoColors.cyan,
          ],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66FFFFFF), blurRadius: 10)],
      ),
      child: const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
    ),
  );
}
