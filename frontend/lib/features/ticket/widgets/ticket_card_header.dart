import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';

/// 카드 한 장의 정보 한 줄. 아이콘 + 문구다.
typedef TicketInfoLine = ({IconData icon, String text});

/// 티켓 카드의 위쪽 — 포스터, 제목, 정보 줄. 예정·지난·양도 세 카드가 똑같이
/// 그린다. 어느 정보 줄을 넣을지는 카드가 정한다(양도 카드에는 공연장이 없다).
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

    // 포스터 높이를 오른쪽 글 묶음(제목 + 정보 줄)에 맞춘다. IntrinsicHeight 로
    // 줄 높이를 글 묶음이 정하게 하고, 포스터는 그 높이를 그대로 받는다.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}

/// 카드 왼쪽 포스터. 폭은 고정, 높이는 부모(글 묶음)가 준 만큼이다. 자식을 전부
/// `Positioned` 로 두어 스스로 높이를 주장하지 않게 한다 — 보통 자식으로 두면
/// 이미지 원본 비율에 따라 줄이 글보다 길어질 수 있다.
class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.badge, required this.dimmed});

  final String? url;
  final Widget? badge;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final poster = PosterImage.network(
      url: url,
      borderRadius: TicketMetrics.posterRadius,
      decodeWidth: TicketMetrics.posterWidth,
    );

    return SizedBox(
      width: TicketMetrics.posterWidth,
      child: Stack(
        children: [
          // 회수된 티켓은 포스터까지 흐리게 한다. 제목만 회색이면 카드가
          // 반쯤만 꺼진 것처럼 보인다.
          Positioned.fill(
            child: dimmed ? Opacity(opacity: 0.45, child: poster) : poster,
          ),
          if (badge case final badge?)
            Positioned(top: 0, left: 0, child: badge),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.line});

  final TicketInfoLine line;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 글자가 한 줄 고정(maxLines: 1)이라 세로 가운데 정렬이 곧 그 줄의 가운데다.
    // 위에 붙이면 줄 높이(≈21)와 아이콘(15)의 차이만큼 아이콘이 위로 떠 보인다.
    return Row(
      children: [
        Icon(
          line.icon,
          size: TicketMetrics.infoIconSize,
          color: AppColors.textSecondary,
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
