import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/artist_summary.dart';
import '../../../core/widgets/artist_photo.dart';
import 'artist_avatar_cell.dart';

/// 인기 아티스트 4×2 격자. 받은 만큼만 그리고 '더보기' 칸은 없다. 칸을 누르면
/// 그 이름으로 검색한다(아티스트 상세 화면은 따로 없다). 스크롤하지 않는 격자라
/// GridView 대신 칸 폭을 계산해 [Wrap] 으로 흘린다.
class ArtistSection extends StatelessWidget {
  const ArtistSection({
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
