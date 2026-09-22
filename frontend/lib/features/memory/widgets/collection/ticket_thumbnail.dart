import 'package:flutter/material.dart';

import '../../models/memory_ticket.dart';
import '../../theme/timo_colors.dart';
import '../ui/catalog_poster.dart';
import '../ui/gradient_text.dart';
import '../ui/local_image.dart';
import '../../constants.dart';

/// Still picture of a ticket for lists: the dark card frame, the stage
/// photo, the person cutout and the brand strip. No shaders or sensors, so
/// a grid full of these stays cheap. [personShift] nudges the person
/// sideways (carousel parallax).
class TicketThumbnail extends StatelessWidget {
  const TicketThumbnail({
    super.key,
    required this.ticket,
    this.personShift = Offset.zero,
    this.radius = 16,
    this.showBrand = true,
  });
  final MemoryTicket ticket;
  final Offset personShift;
  final double radius;
  final bool showBrand;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF15181F),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius - 3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0B0F1A)),
          LocalImage(ticket.backgroundPath, fit: BoxFit.cover, cacheWidth: 600),
          if (ticket.personCompositePath != null)
            Transform.translate(
              offset: personShift,
              child: Transform.scale(
                scale: ticket.manualPersonLayout
                    ? 1
                    : ViewerConstants.personScale,
                child: LocalImage(
                  ticket.personCompositePath!,
                  fit: BoxFit.contain,
                  cacheWidth: 600,
                ),
              ),
            ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x00000000),
                    Color(0x8C000000),
                  ],
                  stops: [0, 0.3, 1],
                ),
              ),
            ),
          ),
          // 확정하지 않은 소장품은 눌러서 보여준다. 딱지만으로는 목록을 훑을
          // 때 눈에 안 들어오고, 흐리기만 하면 왜 흐린지 알 수 없다.
          if (!ticket.confirmed) ...[
            const IgnorePointer(child: ColoredBox(color: Color(0x73000000))),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: TimoColors.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  CollectionText.draftBadge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF3A2A00),
                  ),
                ),
              ),
            ),
          ],
          if (showBrand) ...[
            Positioned(
              left: 12,
              top: 10,
              child: Text(
                'INTERACTIVE MEMORY',
                style: TextStyle(
                  fontSize: 7,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ticket.details['공연명'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          ticket.details['날짜'] ?? '',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GradientText(
                    'TIMO',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 아직 소장품을 만들지 않은 칸: 그 공연의 포스터를 흑백으로 눌러 둔다.
///
/// 예전에는 빈 회색 사각형이었다. 어느 공연 자리인지 화면에서 알 수가 없어
/// 회색 칸이 여러 개면 서로 구분되지 않았다. 포스터를 남기되 채도와 밝기를
/// 죽여 "만든 것"과 한눈에 갈리게 한다.
class TicketPlaceholder extends StatelessWidget {
  const TicketPlaceholder({
    super.key,
    required this.poster,
    required this.title,
    this.radius = 16,
  });
  final String poster, title;
  final double radius;

  /// 휘도만 남기는 흑백 변환.
  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  /// 서버 주소일 수도, 데모 에셋일 수도 있다. 못 읽거나 아예 없으면 바탕색만
  /// 남아 예전 회색 칸과 같아진다.
  Widget _poster() {
    final image = catalogPosterImage(poster);
    if (image == null) return const SizedBox.shrink();
    return Image(
      image: image,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: TimoColors.placeholder,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: _greyscale,
            child: Opacity(opacity: 0.5, child: _poster()),
          ),
          // 글자가 앉을 아래쪽을 밝게 덮어 대비를 만든다.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00F1F2F5), Color(0xF2F1F2F5)],
                stops: [0.4, 0.92],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: TimoColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: TimoColors.brandMid,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      CollectionText.makeLabel,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: TimoColors.brandMid,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 서버에는 있는데 이 기기에는 없는 소장품 칸. 누르면 가져온다.
///
/// [TicketPlaceholder] 와 달리 색을 죽이지 않는다 — 만들지 않은 칸이 아니라
/// **이미 만든** 칸이고, 다만 이 기기에 없을 뿐이다. 미리보기가 없으면 포스터를
/// 대신 쓴다. 가져오는 중이면 아래 글자 대신 도는 표시가 앉는다.
class RemoteTicketCard extends StatelessWidget {
  const RemoteTicketCard({
    super.key,
    required this.poster,
    required this.title,
    this.previewUrl,
    this.restoring = false,
    this.radius = 16,
  });
  final String poster, title;
  final String? previewUrl;
  final bool restoring;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final image = catalogPosterImage(previewUrl ?? poster);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF15181F),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC000000)],
                  stops: [0.3, 1],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  CollectionText.remoteLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: TimoColors.ink,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (restoring)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Row(
                      children: [
                        Icon(
                          Icons.cloud_download_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 3),
                        Text(
                          CollectionText.restoreLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
