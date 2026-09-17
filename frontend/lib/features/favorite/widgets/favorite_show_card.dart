import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/favorite_show.dart';

/// 찜한 공연 한 장. 왼쪽 포스터, 오른쪽에 제목·일시·공연장, 귀퉁이에 하트.
///
/// 판매가 끝난 공연은 아래에 `판매 종료` 뱃지가 붙는다. 데이터 출처는 모른다 —
/// [FavoriteShow] 하나와 콜백 둘만 받는다.
class FavoriteShowCard extends StatelessWidget {
  const FavoriteShowCard({
    super.key,
    required this.show,
    required this.onPressed,
    required this.onUnfavoritePressed,
  });

  final FavoriteShow show;
  final VoidCallback onPressed;
  final VoidCallback onUnfavoritePressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(FavoriteMetrics.showCardRadius);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(FavoriteMetrics.showCardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: FavoriteMetrics.posterWidth,
                height:
                    FavoriteMetrics.posterWidth /
                    FavoriteMetrics.posterAspectRatio,
                child: PosterImage.network(
                  url: show.posterImageUrl,
                  borderRadius: FavoriteMetrics.posterRadius,
                  decodeWidth: FavoriteMetrics.posterWidth,
                ),
              ),
              const SizedBox(width: FavoriteMetrics.posterGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            // 하트 버튼의 터치 영역이 제목보다 위로 튀어나와
                            // 있어 제목을 그만큼 내려 첫 줄을 맞춘다.
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              show.title,
                              style: textTheme.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onUnfavoritePressed,
                          tooltip: FavoriteStrings.unfavorite,
                          iconSize: FavoriteMetrics.favoriteIconSize,
                          color: AppColors.primary,
                          icon: const Icon(Icons.favorite),
                        ),
                      ],
                    ),
                    _MetaLine(
                      icon: Icons.calendar_today_outlined,
                      text: show.dateLabel,
                    ),
                    const SizedBox(height: FavoriteMetrics.cardLineGap),
                    _MetaLine(icon: Icons.place_outlined, text: show.venueName),
                    if (!show.isOnSale) ...[
                      const SizedBox(height: FavoriteMetrics.cardLineGap * 2),
                      const _ClosedBadge(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 작은 아이콘 + 회색 글자 한 줄. 일시와 공연장이 같은 모양이다.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: FavoriteMetrics.cardMetaIconSize,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: FavoriteMetrics.cardMetaIconGap),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// `판매 종료`. 회색 상자에 진한 글자 — 연한 회색 글자는 회색 배경 위에서 대비가
/// 모자란다.
class _ClosedBadge extends StatelessWidget {
  const _ClosedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(FavoriteMetrics.statusBadgeRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        FavoriteStrings.closedBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
