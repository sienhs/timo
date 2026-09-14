import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import '../../../core/widgets/poster_image.dart';

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
          final cellWidth =
              constraints.maxWidth / HomeMetrics.artistColumns;
          return Wrap(
            runSpacing: HomeMetrics.artistRowGap,
            children: [
              for (final artist in artists)
                SizedBox(
                  width: cellWidth,
                  child: _ArtistCell(
                    label: artist.name,
                    onPressed: () => onArtistPressed(artist),
                    child: _ArtistFace(artist: artist),
                  ),
                ),
              SizedBox(
                width: cellWidth,
                child: _ArtistCell(
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

/// 원형 이미지 + 아래 이름. 이미지 부분만 [child] 로 갈아끼운다.
class _ArtistCell extends StatelessWidget {
  const _ArtistCell({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        // 원(CircleBorder)으로 자르면 칸보다 큰 원이 아바타 밖으로 비어져
        // 나온다. 칸 모양을 따라 덮게 둔다.
        borderRadius: BorderRadius.circular(HomeMetrics.artistCellRadius),
        child: Column(
          children: [
            ClipOval(
              child: SizedBox(
                width: HomeMetrics.artistAvatarSize,
                height: HomeMetrics.artistAvatarSize,
                child: child,
              ),
            ),
            const SizedBox(height: HomeMetrics.artistNameGap),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 프로필 사진. 사진이 없는 아티스트는 이름 첫 글자로 대신한다.
class _ArtistFace extends StatelessWidget {
  const _ArtistFace({required this.artist});

  final ArtistSummary artist;

  @override
  Widget build(BuildContext context) {
    final photo = artist.profileImageUrl;
    if (photo != null) {
      return PosterImage.network(
        url: photo,
        decodeWidth: HomeMetrics.artistAvatarSize,
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
