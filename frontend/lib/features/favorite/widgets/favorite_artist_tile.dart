import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/favorite_artist.dart';

/// 찜한 아티스트 한 줄. 원형 사진, 이름, 초록 보조 문구, 오른쪽에 하트.
///
/// 줄을 누르면 그 이름으로 공연을 검색한다 — 아티스트 상세가 아직 없어서다.
/// 시안의 보조 문구(`예정된 공연 2개`)는 서버가 있어야 셀 수 있어, 지금은
/// 누르면 무슨 일이 일어나는지 알리는 말([FavoriteStrings.artistSearchAction])
/// 을 그 자리에 둔다.
class FavoriteArtistTile extends StatelessWidget {
  const FavoriteArtistTile({
    super.key,
    required this.artist,
    required this.onPressed,
    required this.onUnfavoritePressed,
  });

  final FavoriteArtist artist;
  final VoidCallback onPressed;
  final VoidCallback onUnfavoritePressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(FavoriteMetrics.artistTileRadius);

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Semantics(
          button: true,
          label: FavoriteStrings.searchShowsOf(artist.name),
          child: Padding(
            padding: const EdgeInsets.all(FavoriteMetrics.artistTilePadding),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: FavoriteMetrics.artistAvatarSize,
                    child: _ArtistFace(artist: artist),
                  ),
                ),
                const SizedBox(width: FavoriteMetrics.artistAvatarGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        style: textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: FavoriteMetrics.cardLineGap),
                      Text(
                        FavoriteStrings.artistSearchAction,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryPressed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
          ),
        ),
      ),
    );
  }
}

/// 프로필 사진. 사진이 없는 아티스트는 이름 첫 글자로 대신한다. 홈의
/// `ArtistFace` 와 같은 규칙이되 저쪽은 홈 모델을 받아서 따로 둔다.
class _ArtistFace extends StatelessWidget {
  const _ArtistFace({required this.artist});

  final FavoriteArtist artist;

  @override
  Widget build(BuildContext context) {
    final photo = artist.profileImageUrl;
    if (photo != null) {
      return PosterImage.network(
        url: photo,
        decodeWidth: FavoriteMetrics.artistAvatarSize,
      );
    }
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Text(
          artist.name.characters.first,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
