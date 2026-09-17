import '../../favorite/models/favorite_artist.dart';
import '../../favorite/models/favorite_show.dart';
import '../models/artist_summary.dart';
import '../models/show_summary.dart';

/// 홈·검색 화면의 공연·아티스트를 찜 목록에 남길 모양으로 바꾼다.
///
/// 찜 모델은 어느 화면에서 찜했든 같은 모양이어야 해서 홈 모델을 모른다.
/// 그래서 변환은 홈 쪽이 든다 — 공연 상세도 자기 모델(`ShowDetail`)을 같은
/// 방식으로 바꾼다(`features/show/utils/favorite_target.dart`).
extension ShowSummaryFavorite on ShowSummary {
  FavoriteShow toFavorite() => FavoriteShow(
    id: id,
    title: title,
    venueName: venueName,
    isOnSale: isOpenOrUpcoming,
    posterImageUrl: posterImageUrl,
    startAt: startAt,
  );
}

extension ArtistSummaryFavorite on ArtistSummary {
  FavoriteArtist toFavorite() =>
      FavoriteArtist(name: name, profileImageUrl: profileImageUrl);
}
