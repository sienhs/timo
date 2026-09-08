import '../models/seat_price.dart';
import '../models/show_artist.dart';
import '../models/show_detail.dart';

/// 공연 상세 목업. 서버 연동 시 이 클래스를 지우고 상세 조회 응답으로
/// 교체한다. 홈의 [MockHomeData] 와 공연이 겹치지만, 둘 다 같은 시점에
/// 사라질 임시 데이터라 한쪽으로 모으지 않았다.
///
/// 제목·기간·오픈 일시는 홈 목업과 **같은 값**이어야 한다. 홈 카드가
/// `2일 후 오픈` 이라고 했는데 상세가 남은 시간을 다르게 세면 데이터가 두 벌인
/// 것이 그대로 드러난다. 홈처럼 오픈 일시만 실행 시각 기준으로 만들어,
/// 언제 실행해도 상태 셋(카운트다운 · 오픈 일시 표기 · 예매중)이 하나씩
/// 나오게 잡았다.
class MockShowDetailData {
  MockShowDetailData._();

  static const _poster = 'assets/images/sample_poster.jpg';

  /// 시안의 안내문. 공연마다 다를 수 있어 공연 데이터에 넣지만, 목업에서는
  /// 모두 같은 문단을 쓴다.
  static const _notice = [
    '본 공연은 포인트로만 결제하실 수 있습니다.',
    '예매 전 보유 포인트를 반드시 확인해 주시기 바라며, 포인트가 부족할 경우 '
        '결제 과정에서 예매가 정상적으로 진행되지 않을 수 있습니다.',
    '또한 본 공연은 1인 1매에 한해 예매 가능하오니 이용에 참고해 주시기 바랍니다.',
  ];

  /// 상세를 찾지 못했을 때 보여 줄 공연. 예매 흐름을 거치지 않고 열린
  /// 경우(딥링크, 화면 단위 테스트)에도 화면이 죽지 않게 한다.
  static ShowDetail get sample => _iu;

  /// 공연 id 로 상세를 찾는다. 모르는 id 면 [sample] 로 대체한다.
  static ShowDetail byId(String? showId) =>
      _byId[showId] ?? sample;

  static Map<String, ShowDetail> get _byId => {
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
    id: 'iu-2026',
    title: '2026 아이유 콘서트',
    venue: '고척스카이돔',
    posterAsset: _poster,
    startAt: DateTime(2026, 11, 1),
    endAt: DateTime(2026, 12, 31),
    // 예매 목업(`MockBookingData`)의 구역 가격과 같은 값이다. 상세에서 본
    // 금액과 좌석 선택 화면의 금액이 다르면 시연 중에 버그로 보인다.
    seatPrices: const [SeatPrice(grade: '모든 좌석', price: 186000)],
    artists: const [ShowArtist(name: '아이유')],
    notice: _notice,
  );

  /// 오늘 밤 오픈 — 하단 바에 남은 시간이 초 단위로 흐른다.
  static final _blackSkirt = ShowDetail(
    id: 'black-skirt-401',
    title: '검정치마 단독공연 : 401',
    venue: '무신사 개러지',
    posterAsset: _poster,
    startAt: DateTime(2026, 9, 20),
    ticketOpenAt: _today.add(const Duration(hours: 22)),
    seatPrices: const [SeatPrice(grade: '전석 스탠딩', price: 99000)],
    artists: const [ShowArtist(name: '검정치마')],
    notice: _notice,
  );

  static final _remind = ShowDetail(
    id: 'remind-2026',
    title: 'REMIND : 리센느',
    venue: '올림픽공원 체조경기장',
    posterAsset: _poster,
    startAt: DateTime(2026, 7, 5),
    endAt: DateTime(2026, 7, 7),
    // 하루 넘게 남았다 — 카운트다운 대신 오픈 일시를 적는다.
    ticketOpenAt: _today.add(const Duration(days: 5, hours: 19)),
    // 등급이 둘인 공연. 가격 카드가 한 줄에 맞춰져 있지 않은지 여기서 드러난다.
    seatPrices: const [
      SeatPrice(grade: 'VIP석', price: 165000),
      SeatPrice(grade: '일반석', price: 132000),
    ],
    artists: const [ShowArtist(name: '리센느')],
    notice: _notice,
  );

  static final _bigbang = ShowDetail(
    id: 'bigbang-2026',
    title: '2026 BIGBANG',
    venue: '고양종합운동장',
    posterAsset: _poster,
    startAt: DateTime(2026, 11, 15),
    ticketOpenAt: _today.add(const Duration(days: 48, hours: 14)),
    seatPrices: const [SeatPrice(grade: '모든 좌석', price: 154000)],
    artists: const [
      ShowArtist(name: '지드래곤'),
      ShowArtist(name: '태양'),
      ShowArtist(name: '대성'),
    ],
    notice: _notice,
  );

  static final _xia = ShowDetail(
    id: 'xia-2026',
    title: '2026 김준수 콘서트 : XIGNATURE',
    venue: '잠실실내체육관',
    posterAsset: _poster,
    startAt: DateTime(2026, 9, 1),
    endAt: DateTime(2026, 9, 3),
    seatPrices: const [SeatPrice(grade: '모든 좌석', price: 143000)],
    artists: const [ShowArtist(name: '김준수')],
    notice: _notice,
  );

  static final _peggyGou = ShowDetail(
    id: 'peggy-gou-2026',
    title: '페기구 THE LOUD SHOW',
    venue: '인천 파라다이스시티',
    posterAsset: _poster,
    startAt: DateTime(2026, 8, 15),
    seatPrices: const [SeatPrice(grade: '전석 스탠딩', price: 121000)],
    artists: const [ShowArtist(name: '페기구')],
    notice: _notice,
  );
}
