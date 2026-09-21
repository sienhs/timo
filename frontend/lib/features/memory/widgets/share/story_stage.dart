import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../../utils/palette_extractor.dart';
import '../viewer/memory_ticket_card.dart';
import 'saffygram_chrome.dart';

/// 스토리 한 장: 소장품 색에서 뽑은 배경 위에 카드가 서 있다.
///
/// [tiltBySensor] 는 이 스토리를 올릴 때 고른 값이다. 켜면 보는 사람이 폰을
/// 기울여 카드를 움직일 수 있고, 끄면 고정된 그림처럼 보인다. 앱의 기울임
/// 설정과는 별개다 — 스토리는 올린 사람이 정한 대로 보여야 한다.
class StoryStage extends StatelessWidget {
  const StoryStage({
    super.key,
    required this.ticket,
    required this.palette,
    required this.tiltBySensor,
    this.showMark = true,
  });
  final MemoryTicket ticket;
  final TicketPalette palette;
  final bool tiltBySensor;
  final bool showMark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.primary, palette.secondary, TimoColors.background],
        stops: const [0, 0.55, 1],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: ViewerConstants.cardAspect,
              child: MemoryTicketCard(
                ticket: ticket,
                glow: palette.accent,
                tiltBySensor: tiltBySensor,
                // 스토리에서는 영상도 뒤집기도 없다. 한 장의 그림처럼 둔다.
                wrap: (photo, _, _) => photo,
              ),
            ),
          ),
          if (tiltBySensor) ...[const SizedBox(height: 18), const _TiltHint()],
          if (showMark) ...[
            const SizedBox(height: 18),
            const SaffygramMark(size: 13),
          ],
        ],
      ),
    ),
  );
}

/// 기울여 볼 수 있다는 것을 알리는 알약. 색만으로 알리지 않고 글자를 단다.
class _TiltHint extends StatelessWidget {
  const _TiltHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white24),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.screen_rotation_rounded, size: 15, color: Colors.white),
        SizedBox(width: 7),
        Text(
          ShareText.tiltHint,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
