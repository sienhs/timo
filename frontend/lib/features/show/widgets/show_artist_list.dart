import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/show_artist.dart';

/// 출연 아티스트를 원형 사진 + 이름으로 늘어놓는다.
///
/// 조작부가 아니다 — 아티스트 상세 화면이 없어서 눌러도 갈 곳이 없다.
/// 누를 수 있게 그려 놓고 아무 일도 없으면 고장으로 읽히므로, 화면이 생길
/// 때 [InkWell] 을 붙인다.
class ShowArtistList extends StatelessWidget {
  const ShowArtistList({super.key, required this.artists});

  final List<ShowArtist> artists;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ShowDetailMetrics.artistGap,
      runSpacing: ShowDetailMetrics.artistGap,
      children: [for (final artist in artists) _ArtistCell(artist: artist)],
    );
  }
}

class _ArtistCell extends StatelessWidget {
  const _ArtistCell({required this.artist});

  final ShowArtist artist;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ShowDetailMetrics.artistAvatarSize,
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: ShowDetailMetrics.artistAvatarSize,
              height: ShowDetailMetrics.artistAvatarSize,
              child: _ArtistFace(artist: artist),
            ),
          ),
          const SizedBox(height: ShowDetailMetrics.artistNameGap),
          Text(
            artist.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 프로필 사진. 에셋이 아직 없는 아티스트는 이름 첫 글자로 대신한다.
class _ArtistFace extends StatelessWidget {
  const _ArtistFace({required this.artist});

  final ShowArtist artist;

  @override
  Widget build(BuildContext context) {
    final photo = artist.photoAsset;
    if (photo != null) {
      return PosterImage.asset(
        assetPath: photo,
        decodeWidth: ShowDetailMetrics.artistAvatarSize,
      );
    }
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Text(
          artist.name.characters.first,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
