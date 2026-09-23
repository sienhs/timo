import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/artist_summary.dart';
import '../../../core/widgets/artist_photo.dart';
import 'artist_avatar_cell.dart';

/// 추천 검색어. 아티스트 원형 아바타 한 줄이고, 누르면 그 이름으로 검색한다.
/// 칸 폭은 홈 격자와 같은 열 수로 나눠 두 화면의 아바타 간격을 맞춘다.
class RecommendedArtistRow extends StatelessWidget {
  const RecommendedArtistRow({
    super.key,
    required this.artists,
    required this.onArtistPressed,
  });

  final List<ArtistSummary> artists;
  final ValueChanged<ArtistSummary> onArtistPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / HomeMetrics.artistColumns;
          return Wrap(
            runSpacing: HomeMetrics.artistRowGap,
            children: [
              for (final artist in artists)
                SizedBox(
                  width: cellWidth,
                  child: ArtistAvatarCell(
                    label: artist.name,
                    semanticLabel: HomeStrings.searchFor(artist.name),
                    onPressed: () => onArtistPressed(artist),
                    child: ArtistPhoto(
                      url: artist.profileImageUrl,
                      size: HomeMetrics.artistAvatarSize,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
