import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../motion/motion_tokens.dart';
import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';
import 'orgel_card_back.dart';
import 'ticket_thumbnail.dart';

/// "내가 만든 소장품 보기" as a music box: tickets stand on a ring around a
/// vertical axis and the whole platform turns. Drag to spin, release to
/// settle on the nearest ticket, tap a side ticket to bring it round, tap
/// the front one to open. Left alone it turns slowly by itself.
class TicketOrgel extends StatefulWidget {
  const TicketOrgel({super.key, required this.tickets, required this.onOpen});
  final List<MemoryTicket> tickets;
  final ValueChanged<MemoryTicket> onOpen;
  @override
  State<TicketOrgel> createState() => _TicketOrgelState();
}

class _TicketOrgelState extends State<TicketOrgel>
    with SingleTickerProviderStateMixin {
  /// Rotation of the platform in radians; slot i sits at
  /// `angle + slotOffset(i)`. Only the user moves it.
  double angle = 0;
  late final AnimationController settle;
  double radius = 1;

  int get slots =>
      math.max(widget.tickets.length, CollectionLayout.orgelMinSlots);
  double get step => 2 * math.pi / slots;
  bool get fullRing => widget.tickets.length >= slots;

  /// Slots are centred on the ring so a partial ring still puts a neighbour
  /// on each side of the front ticket.
  double slotOffset(int i) => (i - (widget.tickets.length - 1) / 2) * step;

  /// Angle of slot [i] folded into -π..π (0 = facing the viewer).
  double slotAngle(int i) {
    final a = (angle + slotOffset(i)) % (2 * math.pi);
    return a > math.pi ? a - 2 * math.pi : a;
  }

  @override
  void initState() {
    super.initState();
    // Create the ticker while this state is active. Creating it lazily from
    // `settleTo` can happen during disposal, when inherited widgets such as
    // TickerMode can no longer be read from the context.
    settle = AnimationController.unbounded(vsync: this, value: 0)
      ..addListener(() => setState(() => angle = settle.value));
    // Open centred so the ring is visible at once; with an even count no
    // slot is centred, so the newest ticket (index 0) takes the front.
    angle = widget.tickets.length.isOdd ? 0 : -slotOffset(0);
  }

  int get front {
    var best = 0;
    for (var i = 1; i < widget.tickets.length; i++) {
      if (slotAngle(i).abs() < slotAngle(best).abs()) best = i;
    }
    return best;
  }

  void onDragStart(DragStartDetails _) => settle.stop();

  void onDragUpdate(DragUpdateDetails d) =>
      setState(() => angle += d.delta.dx / radius);

  void onDragEnd(DragEndDetails d) {
    final omega = d.velocity.pixelsPerSecond.dx / radius;
    settleTo(angle + omega * CollectionLayout.orgelFlingLookahead, omega);
  }

  /// Spring the platform so the ticket nearest [target] faces the viewer,
  /// starting with angular velocity [omega] (rad/s) from the fling.
  void settleTo(double target, [double omega = 0]) {
    // Snap on the ticket grid (which is offset by half a step when the
    // count is even), never on the gaps between tickets.
    final origin = -slotOffset(0);
    var snapped = origin + ((target - origin) / step).roundToDouble() * step;
    if (!fullRing) {
      // A partial ring cannot turn past its first or last ticket.
      snapped = snapped.clamp(
        -slotOffset(widget.tickets.length - 1),
        -slotOffset(0),
      );
    }
    if (Motion.reduced(context)) {
      setState(() => angle = snapped);
      return;
    }
    settle.animateWith(
      SpringSimulation(CollectionLayout.orgelSpring, angle, snapped, omega),
    );
  }

  void bringToFront(int i) {
    // Nearest equivalent of "slot i at angle 0" to the current rotation.
    var target = -slotOffset(i);
    while (target - angle > math.pi) {
      target -= 2 * math.pi;
    }
    while (angle - target > math.pi) {
      target += 2 * math.pi;
    }
    settleTo(target);
  }

  void tapCard(int i) {
    if (i == front && slotAngle(i).abs() < step / 2) {
      widget.onOpen(widget.tickets[i]);
    } else {
      bringToFront(i);
    }
  }

  @override
  void dispose() {
    settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = widget.tickets;
    final current = tickets[front];
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              // Tall as the box allows, but never wider than the front
              // share of the screen (landscape, tablets).
              final cardH = math.min(
                box.maxHeight * CollectionLayout.orgelCardHeightFactor,
                box.maxWidth *
                    CollectionLayout.orgelCardWidthFactor /
                    CollectionLayout.cardAspect,
              );
              final cardW = cardH * CollectionLayout.cardAspect;
              radius = cardW * CollectionLayout.orgelRadiusFactor;
              final centre = Offset(box.maxWidth / 2, box.maxHeight * 0.47);
              // Farthest first so the front ticket paints on top.
              final order = List<int>.generate(tickets.length, (i) => i)
                ..sort(
                  (a, b) =>
                      math.cos(slotAngle(a)).compareTo(math.cos(slotAngle(b))),
                );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: onDragStart,
                onHorizontalDragUpdate: onDragUpdate,
                onHorizontalDragEnd: onDragEnd,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PlatformPainter(
                          centre: centre + Offset(0, cardH / 2 + 6),
                          radius: radius,
                          cards: [for (final i in order) slotAngle(i)],
                        ),
                      ),
                    ),
                    for (final i in order) _card(i, cardW, cardH, centre),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: CollectionLayout.orgelCaptionGap),
        AnimatedSwitcher(
          duration: Motion.base,
          switchInCurve: Motion.emphasized,
          child: Column(
            key: ValueKey(current.ticketId),
            children: [
              Text(
                current.details['공연명'] ?? '',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: TimoColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${current.details['아티스트'] ?? ''} · ${current.details['날짜'] ?? ''}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: TimoColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < tickets.length; i++)
              AnimatedContainer(
                duration: Motion.base,
                curve: Motion.emphasized,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == front ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == front
                      ? TimoColors.brandMid
                      : TimoColors.placeholder,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (tickets.length > 1)
          const Text(
            CollectionText.swipeHint,
            style: TextStyle(fontSize: 11.5, color: TimoColors.inkTertiary),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(int i, double cardW, double cardH, Offset centre) {
    final theta = slotAngle(i);
    // Ring position: x along the screen, depth away from the viewer,
    // and a small rise so we look slightly down onto the platform.
    final x = math.sin(theta) * radius;
    final depth = (1 - math.cos(theta)) * radius;
    final y = -depth * CollectionLayout.orgelRise;
    final away = (depth / (2 * radius)).clamp(0.0, 1.0);
    final boost =
        1 + CollectionLayout.orgelFrontBoost * math.max(0, math.cos(theta));
    final transform = Matrix4.identity()
      ..setEntry(3, 2, CollectionLayout.orgelPerspective)
      ..translateByDouble(x, y, depth, 1)
      ..rotateY(-theta)
      ..scaleByDouble(boost, boost, 1, 1);
    final ticket = widget.tickets[i];
    // Past 90° we see the card from behind: the dark embossed back.
    final facingAway = math.cos(theta) < 0;
    return Positioned(
      left: centre.dx - cardW / 2,
      top: centre.dy - cardH / 2,
      width: cardW,
      height: cardH,
      child: Transform(
        transform: transform,
        alignment: Alignment.center,
        child: Semantics(
          button: true,
          label: ticket.details['공연명'],
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => tapCard(i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (facingAway)
                  OrgelCardBack(ticket: ticket)
                else
                  TicketThumbnail(
                    ticket: ticket,
                    personShift: Offset(
                      math.sin(theta) * CollectionLayout.personParallax,
                      0,
                    ),
                  ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withValues(
                        alpha:
                            away *
                            (facingAway
                                ? CollectionLayout.orgelBackDim
                                : CollectionLayout.orgelDepthDim),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The turntable under the tickets: a soft disc, a hairline rim, the axle
/// hub, and a blurred shadow under each card.
class _PlatformPainter extends CustomPainter {
  const _PlatformPainter({
    required this.centre,
    required this.radius,
    required this.cards,
  });
  final Offset centre;
  final double radius;
  final List<double> cards;

  @override
  void paint(Canvas canvas, Size size) {
    final rx = radius * 1.12;
    final ry = rx * CollectionLayout.orgelPlatformSqueeze;
    final disc = Rect.fromCenter(center: centre, width: rx * 2, height: ry * 2);
    canvas.drawOval(
      disc,
      Paint()
        ..shader = RadialGradient(
          colors: [
            TimoColors.brandSoft.withValues(alpha: 0.9),
            TimoColors.paperMuted,
            TimoColors.paperMuted.withValues(alpha: 0),
          ],
          stops: const [0, 0.7, 1],
        ).createShader(disc),
    );
    canvas.drawOval(
      disc.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = TimoColors.line,
    );
    // Card shadows follow their ring position.
    final shadow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (final theta in cards) {
      final near = (1 + math.cos(theta)) / 2;
      final p =
          centre +
          Offset(math.sin(theta) * radius, -math.cos(theta) * ry * 0.9);
      shadow.color = TimoColors.ink.withValues(alpha: 0.05 + 0.12 * near);
      canvas.drawOval(
        Rect.fromCenter(
          center: p,
          width: radius * (0.5 + 0.3 * near),
          height: 10 + 8 * near,
        ),
        shadow,
      );
    }
  }

  @override
  bool shouldRepaint(_PlatformPainter old) =>
      old.centre != centre || old.radius != radius || old.cards != cards;
}
