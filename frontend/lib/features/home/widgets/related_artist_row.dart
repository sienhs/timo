import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import 'artist_avatar_cell.dart';

/// 검색 결과의 관련 아티스트. 하트가 붙은 원형 아바타를 가로로 늘어놓는다.
///
/// 아바타를 누르면 그 이름으로 다시 검색한다. 아티스트 상세가 아직 없어서다.
/// 하트는 화면이 넘긴 [onFavoritePressed] 를 부를 뿐 여기서 상태를 갖지 않는다
/// — 찜 API 가 없어 지금은 화면이 안내만 띄운다.
class RelatedArtistRow extends StatelessWidget {
  const RelatedArtistRow({
    super.key,
    required this.artists,
    required this.onArtistPressed,
    required this.onFavoritePressed,
  });

  final List<ArtistSummary> artists;
  final ValueChanged<ArtistSummary> onArtistPressed;
  final ValueChanged<ArtistSummary> onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
      ),
      child: Row(
        children: [
          for (final artist in artists)
            SizedBox(
              width: HomeMetrics.relatedArtistCellWidth,
              child: ArtistAvatarCell(
                label: artist.name,
                semanticLabel: HomeStrings.searchFor(artist.name),
                onPressed: () => onArtistPressed(artist),
                badge: _FavoriteBadge(
                  onPressed: () => onFavoritePressed(artist),
                ),
                child: ArtistFace(artist: artist),
              ),
            ),
        ],
      ),
    );
  }
}

/// 아바타 귀퉁이의 하트. 흰 원 위에 얹어 사진 위에서도 보이게 한다.
class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge({required this.onPressed});

  final VoidCallback onPressed;

  static const _size = 28.0;
  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: HomeStrings.favorite,
        iconSize: _iconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: _size, height: _size),
        color: AppColors.accent,
        icon: const Icon(Icons.favorite_border),
      ),
    );
  }
}
