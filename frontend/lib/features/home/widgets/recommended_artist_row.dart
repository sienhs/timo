import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/artist_summary.dart';
import 'artist_avatar_cell.dart';

/// 추천 검색어. 아티스트 원형 아바타 한 줄이고, 누르면 그 이름으로 검색한다.
///
/// 홈의 인기 아티스트 격자와 칸은 같지만 '더보기' 가 없고 한 줄만이다. 칸 폭은
/// 격자와 같은 열 수로 나눠 두 화면의 아바타 간격이 같아 보이게 한다.
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
                    child: ArtistFace(artist: artist),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
