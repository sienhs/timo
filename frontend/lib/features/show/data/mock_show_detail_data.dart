import '../models/show_artist.dart';
import '../models/show_detail.dart';
import '../models/zone_price.dart';

/// 서버 없이 상세 화면을 볼 때 쓰는 고정 공연. `MockShowApi` 가 이 값을
/// 돌려준다(예매의 `MockBookingData` 와 같은 자리다).
///
/// 제목·날짜·오픈 일시는 홈 목업과 **같은 값**이어야 한다. 홈 카드가
/// `2일 후 오픈` 이라고 했는데 상세가 남은 시간을 다르게 세면 데이터가 두 벌인
/// 것이 그대로 드러난다. 홈처럼 오픈 일시만 실행 시각 기준으로 만들어,
/// 언제 실행해도 상태 셋(카운트다운 · 오픈 일시 표기 · 예매중)이 하나씩
/// 나오게 잡았다.
///
/// 포스터는 서버가 주는 주소를 쓰게 바뀌어 목업에는 넣지 않는다. 자리만
/// 회색으로 그려진다.
class MockShowDetailData {
  MockShowDetailData._();

  /// 상세를 찾지 못했을 때 보여 줄 공연. 예매 흐름을 거치지 않고 열린
  /// 경우(딥링크, 화면 단위 테스트)에도 화면이 죽지 않게 한다.
  static ShowDetail get sample => _iu;

  /// 공연 번호로 상세를 찾는다. 모르는 번호면 [sample] 로 대체한다.
  static ShowDetail byId(int? showId) => _byId[showId] ?? sample;

  static Map<int, ShowDetail> get _byId => {
    for (final detail in all) detail.id: detail,
  };

  static List<ShowDetail> get all => [
    _iu,
    _blackSkirt,
    _remind,
    _bigbang,
    _xia,
    _peggyGou,
  ];

  /// 오늘 자정. 오픈 일시를 여기서 더해 만든다(홈 목업과 같은 기준).
  static DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 이미 오픈한 대표 공연. 예매 목업(`MockBookingData`)이 이 공연이라
  /// 배너 -> 상세 -> 예매로 이어지는 길이 늘 열려 있어야 한다.
  static final _iu = ShowDetail(
    id: 1,
    title: '2026 아이유 콘서트',
    venue: '고척스카이돔',
    startAt: DateTime(2026, 11, 1),
    status: ShowStatus.onSale,
    // 예매 목업(`MockBookingData`)의 구역 가격과 같은 값이다. 상세에서 본
    // 금액과 좌석 선택 화면의 금액이 다르면 시연 중에 버그로 보인다.
    zonePrices: const [ZonePrice(zoneName: '전 구역', price: 186000)],
    artists: const [ShowArtist(name: '아이유')],
  );

  /// 오늘 밤 오픈 — 하단 바에 남은 시간이 초 단위로 흐른다.
  static final _blackSkirt = ShowDetail(
    id: 4,
    title: '검정치마 단독공연 : 401',
    venue: '무신사 개러지',
    startAt: DateTime(2026, 9, 20),
    ticketOpenAt: _today.add(const Duration(hours: 22)),
    status: ShowStatus.scheduled,
    zonePrices: const [ZonePrice(zoneName: '전 구역 스탠딩', price: 99000)],
    artists: const [ShowArtist(name: '검정치마')],
  );

  static final _remind = ShowDetail(
    id: 2,
    title: 'REMIND : 리센느',
    venue: '올림픽공원 체조경기장',
    startAt: DateTime(2026, 7, 5),
    // 하루 넘게 남았다 — 카운트다운 대신 오픈 일시를 적는다.
    ticketOpenAt: _today.add(const Duration(days: 5, hours: 19)),
    status: ShowStatus.scheduled,
    // 구역이 둘인 공연. 가격 카드가 한 줄에 맞춰져 있지 않은지 여기서 드러난다.
    zonePrices: const [
      ZonePrice(zoneName: '1층 A블록', price: 165000),
      ZonePrice(zoneName: '2층 C블록', price: 132000),
    ],
    artists: const [ShowArtist(name: '리센느')],
  );

  static final _bigbang = ShowDetail(
    id: 3,
    title: '2026 BIGBANG',
    venue: '고양종합운동장',
    startAt: DateTime(2026, 11, 15),
    ticketOpenAt: _today.add(const Duration(days: 48, hours: 14)),
    status: ShowStatus.scheduled,
    zonePrices: const [ZonePrice(zoneName: '전 구역', price: 154000)],
    artists: const [
      ShowArtist(name: '지드래곤'),
      ShowArtist(name: '태양'),
      ShowArtist(name: '대성'),
    ],
  );

  static final _xia = ShowDetail(
    id: 5,
    title: '2026 김준수 콘서트 : XIGNATURE',
    venue: '잠실실내체육관',
    startAt: DateTime(2026, 9, 1),
    status: ShowStatus.onSale,
    zonePrices: const [ZonePrice(zoneName: '전 구역', price: 143000)],
    artists: const [ShowArtist(name: '김준수')],
  );

  static final _peggyGou = ShowDetail(
    id: 6,
    title: '페기구 THE LOUD SHOW',
    venue: '인천 파라다이스시티',
    startAt: DateTime(2026, 8, 15),
    status: ShowStatus.onSale,
    zonePrices: const [ZonePrice(zoneName: '전 구역 스탠딩', price: 121000)],
    artists: const [ShowArtist(name: '페기구')],
  );
}
