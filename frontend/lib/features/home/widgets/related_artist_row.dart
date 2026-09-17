import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import 'artist_avatar_cell.dart';

/// 검색 결과의 관련 아티스트. 하트가 붙은 원형 아바타를 가로로 늘어놓는다.
///
/// 아바타를 누르면 그 이름으로 다시 검색한다. 아티스트 상세가 아직 없어서다.
/// 하트는 화면이 넘긴 [onFavoritePressed] 를 부를 뿐 여기서 상태를 갖지 않는다
/// — 누가 찜돼 있는지는 [favoriteNames] 로 받아 채운 하트로 그린다.
class RelatedArtistRow extends StatelessWidget {
  const RelatedArtistRow({
    super.key,
    required this.artists,
    required this.onArtistPressed,
    required this.onFavoritePressed,
    this.favoriteNames = const {},
  });

  final List<ArtistSummary> artists;
  final ValueChanged<ArtistSummary> onArtistPressed;
  final ValueChanged<ArtistSummary> onFavoritePressed;

  /// 찜한 아티스트 이름. 아티스트에 id 가 없어 이름으로 가른다.
  final Set<String> favoriteNames;

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
                  isFavorite: favoriteNames.contains(artist.name),
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
  const _FavoriteBadge({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
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
        tooltip: isFavorite ? HomeStrings.unfavorite : HomeStrings.favorite,
        iconSize: _iconSize,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: _size, height: _size),
        color: AppColors.accent,
        icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
      ),
    );
  }
}
