import '../constants.dart';
import 'listing.dart';
import 'market_concert.dart';

/// 공연 선택 화면의 정렬 탭.
///
/// **서버는 정렬 조건을 받지 않는다.** 마켓의 목록 API 는 의미 있는 순서가
/// 하나뿐이라고 보고 공연은 임박순으로 고정해 준다(백엔드 `MarketListRequestDto`).
/// 그래서 탭 전환은 받아 둔 목록을 앱에서 다시 세우는 일이다 — 한 번에 다
/// 받으므로([ResaleMetrics.pageSize]) 순서만 바꾸면 된다.
enum ConcertSort {
  /// 매물이 많은 공연부터.
  ///
  /// 시안의 이름은 `인기순` 이지만 서버에는 인기를 재는 값이 없다. 관심 수도
  /// 조회 수도 마켓 응답에 없고, 있는 것은 매물 수뿐이다. 양도마켓에서는
  /// 매물이 몰린 공연이 곧 사람이 몰린 공연이라 이 값을 대신 쓴다. 인기 지표가
  /// 응답에 실리면 비교 함수만 바뀐다.
  popular(ResaleStrings.sortPopular),

  /// 공연이 임박한 것부터. 서버가 주는 순서와 같다.
  deadline(ResaleStrings.sortDeadline);

  const ConcertSort(this.label);

  final String label;

  /// 새 목록을 만들어 돌려준다. 받은 목록을 제자리에서 뒤집지 않는다 —
  /// 화면이 들고 있는 원본이 탭을 누를 때마다 섞이면 어느 순서가 원본인지
  /// 알 수 없게 된다.
  List<MarketConcert> sorted(List<MarketConcert> concerts) =>
      [...concerts]..sort(switch (this) {
        ConcertSort.popular => _byListingCount,
        ConcertSort.deadline => _byStartAt,
      });

  /// 매물 많은 순. 같으면 임박한 공연이 앞이다.
  static int _byListingCount(MarketConcert a, MarketConcert b) {
    final byCount = b.listingCount.compareTo(a.listingCount);
    return byCount != 0 ? byCount : _byStartAt(a, b);
  }

  /// 임박한 공연 순. 일정이 아직 없는 공연은 뒤로 민다 — 날짜를 모르는 것과
  /// 먼 것은 다르지만, 임박순에서 맨 앞에 놓을 근거는 없다.
  static int _byStartAt(MarketConcert a, MarketConcert b) {
    final x = a.startAt;
    final y = b.startAt;
    if (x == null || y == null) {
      if (x == y) return a.concertId.compareTo(b.concertId);
      return x == null ? 1 : -1;
    }
    final byStart = x.compareTo(y);
    return byStart != 0 ? byStart : a.concertId.compareTo(b.concertId);
  }
}

/// 매물 목록 화면의 정렬 탭. 공연 정렬과 같은 이유로 앱이 세운다.
enum ListingSort {
  /// 방금 올라온 매물부터.
  latest(ResaleStrings.sortLatest),

  /// 싼 매물부터. 서버가 주는 순서와 같다.
  lowestPrice(ResaleStrings.sortLowestPrice);

  const ListingSort(this.label);

  final String label;

  List<Listing> sorted(List<Listing> listings) =>
      [...listings]..sort(switch (this) {
        ListingSort.latest => _byListedAt,
        ListingSort.lowestPrice => _byPrice,
      });

  /// 최신 등록순. 같은 시각이면 나중에 생긴 매물(번호가 큰 쪽)이 앞이다.
  static int _byListedAt(Listing a, Listing b) {
    final byListedAt = b.listedAt.compareTo(a.listedAt);
    return byListedAt != 0 ? byListedAt : b.listingId.compareTo(a.listingId);
  }

  /// 낮은 가격순. 동가는 번호 오름차순으로 고정한다 — 서버가 페이지 경계에서
  /// 같은 매물이 두 번 나오지 않게 쓰는 기준과 같다.
  static int _byPrice(Listing a, Listing b) {
    final byPrice = a.price.compareTo(b.price);
    return byPrice != 0 ? byPrice : a.listingId.compareTo(b.listingId);
  }
}
