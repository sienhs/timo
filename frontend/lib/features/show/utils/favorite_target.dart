import '../../favorite/models/favorite_show.dart';
import '../models/show_detail.dart';

/// 공연 상세를 찜 목록에 남길 모양으로 바꾼다. 홈의 `favorite_targets.dart` 와 같은 역할.
/// 오픈 예정(`scheduled`)도 판매 중으로 친다 — 찜리스트 필터가 '판매 중 / 판매 종료'
/// 둘뿐이라 곧 살 수 있는 공연을 종료 쪽에 넣을 수 없다(홈 `isOpenOrUpcoming` 과 같은 기준).
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
