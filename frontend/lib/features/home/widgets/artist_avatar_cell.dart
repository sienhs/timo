import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/poster_image.dart';
import '../constants.dart';
import '../models/artist_summary.dart';

/// 원형 이미지 + 아래 이름. 홈의 인기 아티스트 격자와 검색 화면의 추천 검색어·
/// 관련 아티스트가 같은 칸을 쓴다. 이미지 부분만 [child] 로 갈아끼우고, [badge]
/// 를 주면 아바타 오른쪽 아래 원 테두리에 걸쳐 얹는다(관련 아티스트의 하트).
class ArtistAvatarCell extends StatelessWidget {
  const ArtistAvatarCell({
    super.key,
    required this.label,
    required this.onPressed,
    required this.child,
    this.semanticLabel,
    this.badge,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  /// 스크린 리더에 읽힐 말. 안 주면 [label] 그대로다. 누르면 검색이 되는 칸은
  /// 이름만 읽으면 무슨 일이 일어나는지 모르니 `{이름} 검색` 으로 준다.
  final String? semanticLabel;

  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: onPressed,
        // 원(CircleBorder)으로 자르면 칸보다 큰 원이 아바타 밖으로 비어져
        // 나온다. 칸 모양을 따라 덮게 둔다.
        borderRadius: BorderRadius.circular(HomeMetrics.artistCellRadius),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: HomeMetrics.artistAvatarSize,
                    height: HomeMetrics.artistAvatarSize,
                    child: child,
                  ),
                ),
                // 원 테두리에 걸치게 아바타 밖으로 조금 내보낸다. Stack 이
                // 자르지 않아(Clip.none) 나간 만큼 그대로 보인다.
                if (badge != null)
                  Positioned(
                    right: -HomeMetrics.artistFavoriteOverhang,
                    bottom: -HomeMetrics.artistFavoriteOverhang,
                    child: badge,
                  ),
              ],
            ),
            const SizedBox(height: HomeMetrics.artistNameGap),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
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
class ArtistFace extends StatelessWidget {
  const ArtistFace({super.key, required this.artist});

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
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
