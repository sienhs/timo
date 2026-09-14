import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';

/// 카드 한 장의 정보 한 줄. 아이콘 + 문구다.
typedef TicketInfoLine = ({IconData icon, String text});

/// 티켓 카드의 위쪽 — 포스터, 제목, 정보 줄.
///
/// 예정·지난·양도 세 카드가 이 부분을 똑같이 그린다. 다른 것은 아래 버튼
/// 줄뿐이라 거기까지 한 위젯에 넣으면 카드마다 쓰지 않는 파라미터가 생긴다.
///
/// 정보 줄을 목록으로 받는 이유: 양도 카드에는 공연장이 없고 예정 카드에는
/// 있다. 어느 줄을 넣을지는 카드가 정한다.
class TicketCardHeader extends StatelessWidget {
  const TicketCardHeader({
    super.key,
    required this.title,
    required this.posterImageUrl,
    required this.infoLines,
    this.badge,
    this.trailing,
    this.dimmed = false,
  });

  final String title;
  final String? posterImageUrl;
  final List<TicketInfoLine> infoLines;

  /// 포스터 왼쪽 위에 얹는 배지. `D-9` · `판매중` 등.
  final Widget? badge;

  /// 제목 오른쪽 끝. 더보기 버튼이 들어간다.
  final Widget? trailing;

  /// 회수된 티켓(환불·취소)이면 색을 죽인다. 목록에 남기되 손댈 수 없음을
  /// 색으로 먼저 알린다.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleColor = dimmed ? AppColors.textSecondary : AppColors.textPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Poster(url: posterImageUrl, badge: badge, dimmed: dimmed),
        const SizedBox(width: TicketMetrics.cardPadding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 8),
              for (final line in infoLines) ...[
                _InfoRow(line: line),
                if (line != infoLines.last) const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.badge, required this.dimmed});

  final String? url;
  final Widget? badge;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final poster = SizedBox(
      width: TicketMetrics.posterWidth,
      height: TicketMetrics.posterHeight,
      child: PosterImage.network(
        url: url,
        borderRadius: TicketMetrics.posterRadius,
        decodeWidth: TicketMetrics.posterWidth,
      ),
    );

    return Stack(
      children: [
        // 회수된 티켓은 포스터까지 흐리게 한다. 제목만 회색이면 카드가
        // 반쯤만 꺼진 것처럼 보인다.
        dimmed ? Opacity(opacity: 0.45, child: poster) : poster,
        if (badge case final badge?) Positioned(top: 0, left: 0, child: badge),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.line});

  final TicketInfoLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 아이콘이 글자 첫 줄 가운데에 오도록 살짝 내린다.
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            line.icon,
            size: TicketMetrics.infoIconSize,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            line.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
