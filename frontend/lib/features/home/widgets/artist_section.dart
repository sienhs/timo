import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import 'artist_avatar_cell.dart';

/// 인기 아티스트 4×2 격자. 마지막 칸은 '더보기' 다.
///
/// GridView 를 쓰지 않는다 — 스크롤하지 않는 8칸짜리 격자에 스크롤 위젯을
/// 넣으면 부모 스크롤과 물려 `shrinkWrap` · `physics` 를 매번 손봐야 한다.
/// 칸 폭만 계산해서 [Wrap] 으로 흘리면 열 수만 바꿔도 배치가 따라온다.
class ArtistSection extends StatelessWidget {
  const ArtistSection({
    super.key,
    required this.artists,
    required this.onArtistPressed,
    required this.onMorePressed,
  });

  final List<ArtistSummary> artists;
  final ValueChanged<ArtistSummary> onArtistPressed;
  final VoidCallback onMorePressed;

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
                    onPressed: () => onArtistPressed(artist),
                    child: ArtistFace(artist: artist),
                  ),
                ),
              SizedBox(
                width: cellWidth,
                child: ArtistAvatarCell(
                  label: HomeStrings.artistMore,
                  onPressed: onMorePressed,
                  child: const ColoredBox(
                    color: AppColors.surfaceMuted,
                    child: Center(
                      child: Icon(Icons.add, color: AppColors.textSecondary),
                    ),
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
