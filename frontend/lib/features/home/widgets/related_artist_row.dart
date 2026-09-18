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
                badge: _FavoriteHeart(
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

/// 아바타 원 테두리에 걸친 하트. 찜 전에는 초록 빈 하트, 찜하면 초록으로
/// 채운다 — 채운 초록 하트가 곧 찜한 상태인 것은 공연 카드(`ShowBannerCard`)·
/// 공연 상세 상단 바·찜리스트와 같다.
///
/// 공연 카드와 달리 빈 하트도 초록이다. 원 밖으로 반쯤 나가 흰 배경에 걸치는
/// 자리라 흰 선 하트는 보이지 않는다.
class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: isFavorite ? HomeStrings.unfavorite : HomeStrings.favorite,
      iconSize: HomeMetrics.artistFavoriteIconSize,
      // 버튼 크기를 못 박는다. Material 3 의 IconButton 은 `constraints` 를
      // 줘도 터치 타깃 규칙(tapTargetSize)으로 48 까지 부풀리는데, 그러면
      // 아이콘 중심이 계산한 자리보다 안쪽으로 밀려 원 안에 들어가 버린다.
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        fixedSize: const Size.square(HomeMetrics.artistFavoriteButtonSize),
        minimumSize: const Size.square(HomeMetrics.artistFavoriteButtonSize),
        maximumSize: const Size.square(HomeMetrics.artistFavoriteButtonSize),
        foregroundColor: AppColors.primary,
      ),
      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
    );
  }
}
