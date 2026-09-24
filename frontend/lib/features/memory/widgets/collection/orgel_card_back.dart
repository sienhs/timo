import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../../utils/ticket_id.dart';
import '../ui/gradient_text.dart';
import '../ui/holo_frame.dart';

/// 오르골에서 축 뒤로 돌아간 티켓의 뒷면.
///
/// 앞면 프레임과 같은 어두운 재질 위에 홀로 테두리 한 줄, 가운데에 라쿤
/// 마스코트를 음각으로 찍었다. 정보는 적지 않는다 — 이 면은 잠깐 지나가고
/// 원근으로 작게 보이는 면이라, 공연 정보는 뷰어의 뒤집기 면이 맡는다.
class OrgelCardBack extends StatelessWidget {
  const OrgelCardBack({super.key, required this.ticket});
  final MemoryTicket ticket;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, box) {
      final width = box.maxWidth;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: TimoColors.cardFrame,
          borderRadius: BorderRadius.circular(TimoRadii.tile),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TimoRadii.tile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _HairlinePainter()),
              Positioned.fill(
                child: HoloFrame(
                  inset: EdgeInsets.symmetric(
                    horizontal: width * CollectionLayout.holoFrameInset,
                    vertical: box.maxHeight * CollectionLayout.holoFrameInset,
                  ),
                  radius: CollectionLayout.holoFrameRadius,
                ),
              ),
              const Align(
                alignment: CollectionLayout.orgelBackSilhouetteAlign,
                child: FractionallySizedBox(
                  widthFactor: CollectionLayout.orgelBackSilhouetteWidth,
                  child: _EmbossedMascot(),
                ),
              ),
              Align(
                alignment: CollectionLayout.orgelBackWordmarkAlign,
                child: GradientText(
                  CollectionText.brand,
                  style: TextStyle(
                    fontSize: width * CollectionLayout.orgelBackWordmarkSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing:
                        width *
                        CollectionLayout.orgelBackWordmarkSize *
                        CollectionLayout.orgelBackWordmarkTracking,
                    height: 1,
                  ),
                ),
              ),
              Align(
                alignment: CollectionLayout.orgelBackLabelAlign,
                child: Text(
                  CollectionText.backLabel,
                  style: TextStyle(
                    fontSize: width * CollectionLayout.orgelBackLabelSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing:
                        width *
                        CollectionLayout.orgelBackLabelSize *
                        CollectionLayout.orgelBackLabelTracking,
                    height: 1,
                    color: TimoColors.textTertiary,
                  ),
                ),
              ),
              Align(
                alignment: CollectionLayout.orgelBackIdAlign,
                child: Text(
                  CollectionText.backNumber(shortTicketId(ticket.ticketId)),
                  style: TextStyle(
                    fontSize: width * CollectionLayout.orgelBackIdSize,
                    fontWeight: FontWeight.w500,
                    height: 1,
                    color: TimoColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 라쿤 실루엣을 재질에 찍은 각인처럼: 반투명 흰 채움 위아래로 어두운 그림자
/// 한 줄, 밝은 하이라이트 한 줄. 색을 더하지 않아 앞 카드와 싸우지 않는다.
class _EmbossedMascot extends StatelessWidget {
  const _EmbossedMascot();

  static const _asset = 'assets/images/mascot_silhouette.png';

  Widget _layer(Color color, double dy) => Transform.translate(
    offset: Offset(0, dy),
    child: Image.asset(
      _asset,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      _layer(
        Colors.black.withValues(
          alpha: CollectionLayout.orgelBackEmbossShadowAlpha,
        ),
        CollectionLayout.orgelBackEmbossOffset,
      ),
      _layer(
        Colors.white.withValues(
          alpha: CollectionLayout.orgelBackEmbossHighlightAlpha,
        ),
        -CollectionLayout.orgelBackEmbossOffset,
      ),
      _layer(
        Colors.white.withValues(alpha: CollectionLayout.orgelBackEmbossAlpha),
        0,
      ),
    ],
  );
}

/// 뒷면 바탕에 깔린 가는 대각선 결.
class _HairlinePainter extends CustomPainter {
  const _HairlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final hairline = Paint()
      ..color = Colors.white.withValues(
        alpha: CollectionLayout.orgelBackHairlineAlpha,
      )
      ..strokeWidth = 1;
    // x + y = k 인 선들: 왼쪽 아래에서 오른쪽 위로 오르는 결.
    for (
      var k = 0.0;
      k < size.width + size.height;
      k += CollectionLayout.orgelBackHairlineGap
    ) {
      canvas.drawLine(Offset(k, 0), Offset(0, k), hairline);
    }
  }

  @override
  bool shouldRepaint(_HairlinePainter old) => false;
}
