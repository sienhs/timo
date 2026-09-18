import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/artist_summary.dart';
import 'artist_avatar_cell.dart';

/// 인기 아티스트 4×2 격자. 받은 만큼만 그리고 '더보기' 칸은 없다 — 아티스트
/// 목록 화면이 없고, 받아 오는 수를 격자 크기에 맞춰 두었다. 칸을 누르면
/// 그 이름으로 검색한다(아티스트 상세 화면은 따로 없다).
///
/// GridView 를 쓰지 않는다 — 스크롤하지 않는 8칸짜리 격자에 스크롤 위젯을
/// 넣으면 부모 스크롤과 물려 `shrinkWrap` · `physics` 를 매번 손봐야 한다.
/// 칸 폭만 계산해서 [Wrap] 으로 흘리면 열 수만 바꿔도 배치가 따라온다.
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
