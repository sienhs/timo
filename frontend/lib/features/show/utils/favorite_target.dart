import '../../favorite/models/favorite_show.dart';
import '../models/show_detail.dart';

/// 공연 상세를 찜 목록에 남길 모양으로 바꾼다. 홈의
/// `features/home/utils/favorite_targets.dart` 와 같은 역할이다.
///
/// 판매 중 여부는 상태만 본다. 오픈 예정(`scheduled`)도 판매 중으로 친다 —
/// 찜리스트의 필터가 '판매 중 / 판매 종료' 둘뿐이고, 곧 살 수 있는 공연을
/// 종료 쪽에 넣을 수는 없어서다. 홈 `ShowSummary.isOpenOrUpcoming` 과 같은 기준이다.
extension ShowDetailFavorite on ShowDetail {
  FavoriteShow toFavorite() => FavoriteShow(
    id: id,
    title: title,
    venueName: venue,
    isOnSale: status == ShowStatus.scheduled || status == ShowStatus.onSale,
    posterImageUrl: posterUrl,
    startAt: startAt,
  );
}
