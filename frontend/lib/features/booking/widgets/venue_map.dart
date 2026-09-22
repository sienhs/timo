import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/zone.dart';

/// 구역 번호 → 구역색. 구역도·좌석 배치도·잔여좌석 목록이 같은 색을 써야 해서
/// 한 곳에서만 정한다.
///
/// 서버 구역 번호는 1 부터라, 구역 다섯 개면 A·B·C·D·E 가 아래 표의 1·2·3·4·0
/// 번째 색을 쓴다. C구역은 갈색(#AD6534)이었는데 탁해 보여 진한 주황으로
/// 바꿨다(사용자 결정).
Color zoneColor(int id) => const [
  Color(0xFF7950B5),
  Color(0xFF356DB5),
  Color(0xFF168577),
  Color(0xFFC2410C),
  Color(0xFFB64E79),
][id.abs() % 5];

/// 공연장 구역 배치도.
///
/// 배치도는 STAGE 아래에 좌(A) · 우(B), 그 밑에 가로로 긴 구역(C), 맨 아래에
/// 같은 크기의 줄을 좌우로 나눈 2층 구역(D · E) 순이다. 주최사가 배치도를 직접
/// 구성하는 기능은 이번 범위 밖이라 좌표 데이터를 두지 않고 이 형태에 구역을
/// **순서대로** 꽂는다. 배치도 편집이 들어오면 이 위젯이 좌표 기반으로 바뀌어야
/// 한다.
///
/// 구역 수가 셋을 넘으면 넷째부터는 맨 아랫줄에 가로로 나눠 넣는다. 서버가 주는
/// 구역 수가 늘어도 그림이 깨지지 않게 하려는 것이다.
///
/// 시안대로 매진 구역도 다른 구역과 같은 색으로 둔다. 매진 여부는 눌렀을 때
/// 화면이 안내한다.
class VenueMap extends StatelessWidget {
  const VenueMap({
    super.key,
    required this.zones,
    required this.onZoneTap,
    this.selectedZoneId,
    this.compact = false,
  });
  final int? selectedZoneId;
  final bool compact;

  /// 서버에서 받은 구역들. 순서가 곧 배치도의 자리다.
  final List<Zone> zones;

  final void Function(Zone zone) onZoneTap;

  static const _flankHeight = 96.0;

  /// 가로로 긴 구역 한 줄의 높이. C 와 그 아래 2층 줄이 같은 크기다.
  static const _bottomHeight = 58.0;

  /// 구역 사이 간격. 붙여 두면 어디까지가 한 구역인지 눈으로 갈리지 않는다.
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FittedBox(
        child: SizedBox(
          width: 300,
          child: VenueMap(
            zones: zones,
            onZoneTap: onZoneTap,
            selectedZoneId: selectedZoneId,
          ),
        ),
      );
    }
    final balcony = zones.skip(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mapSurface,
        border: Border.all(color: AppColors.border),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(14),
          bottom: Radius.circular(32),
        ),
      ),
      child: Column(
        // stretch 가 없으면 FLOOR C 처럼 Expanded 밖에 있는 구역이 글자 폭으로
        // 쪼그라든다(Column 기본 정렬이 center 라서).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StageBar(),
          SizedBox(
            height: _flankHeight,
            child: Row(
              // 무대 돌출부는 글자가 없어 제 높이가 없다. stretch 가 없으면
              // Row 기본 정렬(center)에 눌려 높이 0 이 되고 T 자가 사라진다.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 36,
                  child: Padding(
                    // 무대와 띄운다. 붙여 두면 분홍 구역이 무대의 일부처럼 읽힌다.
                    padding: const EdgeInsets.only(top: _gap, right: _gap),
                    child: zones.isEmpty
                        ? const SizedBox()
                        : _ZoneBlock(
                            zone: zones[0],
                            shape: _ZoneShape.left,
                            onTap: onZoneTap,
                            selected: selectedZoneId == zones[0].id,
                          ),
                  ),
                ),
                // 무대 돌출부. STAGE 바와 이어져 시안의 T 자 형태를 만든다.
                // 여기에만 위쪽 여백을 주지 않는 이유가 그것이다.
                const Expanded(
                  flex: 28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.stageFill,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 36,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _gap, left: _gap),
                    child: zones.length < 2
                        ? const SizedBox()
                        : _ZoneBlock(
                            zone: zones[1],
                            shape: _ZoneShape.right,
                            onTap: onZoneTap,
                            selected: selectedZoneId == zones[1].id,
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (zones.length >= 3) ...[
            const SizedBox(height: _gap),
            SizedBox(
              height: _bottomHeight,
              child: _ZoneBlock(
                zone: zones[2],
                shape: _ZoneShape.rear,
                onTap: onZoneTap,
                selected: selectedZoneId == zones[2].id,
              ),
            ),
          ],
          // 2층 줄. C 와 같은 크기의 줄을 구역 수만큼 나눠 쓴다.
          if (balcony.isNotEmpty) ...[
            const SizedBox(height: _gap),
            SizedBox(
              height: _bottomHeight,
              child: Row(
                children: [
                  for (var i = 0; i < balcony.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: _ZoneBlock(
                        zone: balcony[i],
                        shape: i == 0
                            ? _ZoneShape.rearLeft
                            : i == balcony.length - 1
                            ? _ZoneShape.rearRight
                            : _ZoneShape.rear,
                        onTap: onZoneTap,
                        selected: selectedZoneId == balcony[i].id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.stageFill,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Text(
        'STAGE',
        // TextStyle 을 새로 만들지 않고 테마를 경유한다. 직접 만들면
        // 나중에 fontFamily 를 지정할 때 이 글자만 기본 폰트로 남는다.
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ZoneBlock extends StatelessWidget {
  const _ZoneBlock({
    required this.zone,
    required this.onTap,
    this.selected = false,
    this.shape = _ZoneShape.rear,
  });
  final _ZoneShape shape;
  final bool selected;

  final Zone zone;
  final void Function(Zone zone) onTap;

  @override
  Widget build(BuildContext context) {
    final block = ClipPath(
      clipper: _ZoneOutline(shape),
      child: CustomPaint(
        painter: _ZoneDetailPainter(shape, zoneColor(zone.id), selected),
        child: Center(
          child: Text(
            zone.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );

    // 매진 구역도 탭은 받는다. 아무 반응이 없으면 사용자는 앱이 멈춘 줄 안다.
    // 매진 안내는 화면(onTap)이 띄운다.
    return GestureDetector(onTap: () => onTap(zone), child: block);
  }
}

enum _ZoneShape { left, right, rear, rearLeft, rearRight }

/// 기존 구역 위치를 유지하고 외곽만 살짝 벌린 개략도다.
class _ZoneOutline extends CustomClipper<Path> {
  const _ZoneOutline(this.shape);
  final _ZoneShape shape;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return switch (shape) {
      _ZoneShape.left =>
        Path()
          ..moveTo(w * .09, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..lineTo(w * .04, h)
          ..quadraticBezierTo(0, h, 0, h * .9)
          ..lineTo(w * .06, h * .1)
          ..quadraticBezierTo(w * .07, 0, w * .09, 0)
          ..close(),
      _ZoneShape.right =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(w * .91, 0)
          ..quadraticBezierTo(w * .93, 0, w * .94, h * .1)
          ..lineTo(w, h * .9)
          ..quadraticBezierTo(w, h, w * .96, h)
          ..lineTo(0, h)
          ..close(),
      // 아래로 갈수록 넓어진다. 좌석표가 그렇기 때문이다(C구역은 1열 18석에서
      // 10열 22석으로 늘어난다). 반대로 그려 두면 구역도와 좌석도가 서로 다른
      // 모양을 말한다.
      //
      // 기울기와 호는 옆 구역들과 어울리게 얕게 둔다(사용자 결정). 세게 주면
      // C구역만 튀어 배치도 전체가 기울어 보인다.
      _ZoneShape.rear =>
        Path()
          ..moveTo(w * .035, 0)
          ..quadraticBezierTo(w * .5, h * .08, w * .965, 0)
          ..lineTo(w, h * .92)
          ..quadraticBezierTo(w * .5, h, 0, h * .92)
          ..close(),
      _ZoneShape.rearLeft =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(w, h * .07)
          ..lineTo(w, h)
          ..quadraticBezierTo(w * .25, h, w * .08, h * .75)
          ..quadraticBezierTo(w * .01, h * .5, 0, 0)
          ..close(),
      _ZoneShape.rearRight =>
        Path()
          ..moveTo(0, h * .07)
          ..lineTo(w, 0)
          ..quadraticBezierTo(w * .99, h * .5, w * .92, h * .75)
          ..quadraticBezierTo(w * .75, h, 0, h)
          ..close(),
    };
  }

  @override
  bool shouldReclip(_ZoneOutline oldClipper) => oldClipper.shape != shape;
}

/// 구역 블록의 면과 테두리를 그린다. 좌석열 질감을 내던 옅은 줄은 뺐다.
class _ZoneDetailPainter extends CustomPainter {
  const _ZoneDetailPainter(this.shape, this.color, this.selected);
  final _ZoneShape shape;
  final Color color;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = _ZoneOutline(shape).getClip(size);
    canvas.drawPath(
      outline,
      Paint()..color = color.withValues(alpha: selected ? .32 : .16),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = color.withValues(alpha: selected ? 1 : .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4 : 1,
    );
  }

  @override
  bool shouldRepaint(_ZoneDetailPainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.selected != selected;
}
