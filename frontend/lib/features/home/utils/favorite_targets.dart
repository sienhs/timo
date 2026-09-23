import '../../favorite/models/favorite_artist.dart';
import '../../favorite/models/favorite_show.dart';
import '../models/artist_summary.dart';
import '../models/show_summary.dart';

/// 홈·검색 화면의 공연·아티스트를 찜 목록에 남길 모양으로 바꾼다. 찜 모델은
/// 홈 모델을 모르므로 변환은 홈 쪽이 든다(공연 상세도 같은 방식).
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
