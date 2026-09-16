import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../ui/gradient_text.dart';
import 'holo_overlay.dart';

/// Ticket stub: concert details, perforation, barcode and demo QR.
class TicketBack extends StatelessWidget {
  const TicketBack({
    super.key,
    required this.ticket,
    required this.tilt,
    required this.time,
  });
  final MemoryTicket ticket;
  final ValueListenable<Offset> tilt;
  final ValueListenable<double> time;
  static const _titleKey = '공연명';
  static const _wideKeys = {'입장 안내', '장소'};

  @override
  Widget build(BuildContext context) {
    final title = ticket.details[_titleKey] ?? '';
    final fields = ticket.details.entries.where((e) => e.key != _titleKey);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF141B2E), Color(0xFF0A0E1A)],
            ),
          ),
        ),
        HoloOverlay(tilt: tilt, time: time, idle: 0.04, active: 0.04),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                'TIMO',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MEMORY TICKET',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: TimoColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (_, c) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final entry in fields)
                          SizedBox(
                            width: _wideKeys.contains(entry.key)
                                ? c.maxWidth
                                : (c.maxWidth - 12) / 2,
                            child: _Field(label: entry.key, value: entry.value),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const _Perforation(),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Semantics(
                      label: '입장 불가 데모 바코드',
                      child: CustomPaint(
                        size: const Size(double.infinity, 34),
                        painter: _Barcode(ticket.ticketId),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: '데모 QR 패턴',
                    child: CustomPaint(
                      size: const Size(44, 44),
                      painter: _DemoQr(ticket.ticketId),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '데모 · 입장 불가  ·  #${ticket.ticketId.substring(ticket.ticketId.length - 6)}',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: TimoColors.textTertiary,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.6,
          color: TimoColors.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: TimoColors.textPrimary,
        ),
      ),
    ],
  );
}


/// Dashed tear line with half-moon notches at both ends.
class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 12,
    width: double.infinity,
    child: CustomPaint(painter: _PerforationPainter()),
  );
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dash = Paint()
      ..color = TimoColors.glassBorder
      ..strokeWidth = 1.2;
    for (var x = 12.0; x < size.width - 12; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
    }
    final notch = Paint()..color = TimoColors.background;
    canvas.drawCircle(Offset(-14, y), 10, notch);
    canvas.drawCircle(Offset(size.width + 14, y), 10, notch);
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => false;
}

class _Barcode extends CustomPainter {
  _Barcode(this.seed);
  final String seed;
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed.hashCode);
    final paint = Paint()..color = TimoColors.textPrimary;
    var x = 0.0;
    while (x < size.width) {
      final w = 1.0 + random.nextInt(3);
      if (random.nextInt(3) != 1) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1;
    }
  }

  @override
  bool shouldRepaint(_Barcode old) => old.seed != seed;
}

class _DemoQr extends CustomPainter {
  _DemoQr(this.seed);
  final String seed;
  static const _cells = 11;
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed.hashCode ^ 0x5bd1e995);
    final cell = size.width / _cells;
    final paint = Paint()..color = TimoColors.textPrimary;
    for (var r = 0; r < _cells; r++) {
      for (var c = 0; c < _cells; c++) {
        final finder =
            (r < 3 && c < 3) ||
            (r < 3 && c > _cells - 4) ||
            (r > _cells - 4 && c < 3);
        final on = finder
            ? !(r == 1 && c == 1 ||
                  r == 1 && c == _cells - 2 ||
                  r == _cells - 2 && c == 1)
            : random.nextBool();
        if (on) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell - 0.6, cell - 0.6),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DemoQr old) => old.seed != seed;
}
