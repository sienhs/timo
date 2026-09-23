import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artist_photo.dart';
import '../constants.dart';
import '../models/show_artist.dart';

/// 출연 아티스트를 원형 사진 + 이름으로 늘어놓는다. 아티스트 상세 화면이 없어
/// 누를 수 없게 그린다 — 화면이 생길 때 [InkWell] 을 붙인다.
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
              child: ArtistPhoto(
                url: artist.photoUrl,
                size: ShowDetailMetrics.artistAvatarSize,
              ),
            ),
          ),
          const SizedBox(height: ShowDetailMetrics.artistNameGap),
          Text(
            artist.name,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
