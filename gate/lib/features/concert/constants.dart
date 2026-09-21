/// 공연 선택 흐름의 치수·문구.
class ConcertMetrics {
  ConcertMetrics._();

  /// 목록 카드 한 장의 포스터 썸네일. 공연 포스터는 세로가 긴 비율이라 너비를
  /// 정하면 높이가 따라온다.
  static const posterWidth = 64.0;
  static const posterAspectRatio = 3 / 4;
  static const posterRadius = 10.0;

  /// 카드 한 장의 최소 높이. 장갑 낀 손으로도 눌러야 해서 터치 최소선(44)보다
  /// 넉넉하다.
  static const tileMinHeight = 88.0;

  /// 목록 카드. 공통 [AppMetrics.cardRadius](12) 보다 둥글다 — 카드가 세로로
  /// 이어 붙는 목록이라 모서리가 덜 둥글면 칸들이 한 덩어리로 보인다.
  static const cardRadius = 16.0;
  static const cardBorderWidth = 1.5;
  static const cardGap = 12.0;

  /// 카드 안쪽 여백. 포스터와 테두리가 붙어 보이지 않을 만큼.
  static const cardPadding = 14.0;

  /// 필터 칩의 모서리·여백. 알약 모양이라 반경은 높이보다 크게 둔다.
  static const chipRadius = 999.0;
  static const chipGap = 8.0;

  /// 불러오는 동안 깔아 둘 빈 카드의 개수. 폰 한 화면을 덮을 만큼만.
  static const skeletonTileCount = 5;

  /// 한 번에 받아 올 공연 수. 목록에 검색이 붙어 있어 더 받아올 이유가 없고,
  /// 서버 상한(100)이기도 하다.
  static const pageSize = 100;

  /// 검색어를 다 친 것으로 보고 서버에 요청하기까지 기다리는 시간. 한 글자마다
  /// 요청하면 공연장 와이파이에서 앞 요청의 응답이 뒤늦게 도착해 목록이 튄다.
  static const searchDebounce = Duration(milliseconds: 300);

  /// 팬 앱이 입장 QR 을 받을 수 있는 시간대. **백엔드 `EntryPassService` 의
  /// `ENTRY_OPENS_BEFORE_START`·`ENTRY_CLOSES_AFTER_START` 와 같은 값이어야
  /// 한다.**
  ///
  /// 서버가 이 창을 응답에 실어 주지 않아 지금은 베껴 두는 수밖에 없다. 게이트가
  /// 이 값으로 하는 일은 '입장 진행 중' 뱃지를 켜고 끄는 것뿐이라, 어긋나도
  /// 검표 자체는 정상이고 뱃지만 몇 분 틀린다. 서버가 창을 바꾸면 여기도 고친다.
  static const entryOpensBefore = Duration(hours: 2);
  static const entryClosesAfter = Duration(minutes: 5);

  /// 가짜 API 의 응답 지연.
  static const mockLatency = Duration(milliseconds: 400);
}

/// 공연 선택 흐름의 문구.
class ConcertStrings {
  ConcertStrings._();

  static const title = '검표할 공연';
  static const subtitle = '이 게이트에서 받을 공연을 골라주세요';
  static const searchHint = '공연명 검색';
  static const clearSearch = '검색어 지우기';

  /// 오늘 하는 공연에 붙는 뱃지. 운영자가 목록에서 찾는 건 거의 항상 이것이다.
  static const today = '오늘';

  /// 지금 팬 앱이 입장 QR 을 발급받을 수 있는 공연에 붙는 뱃지. '오늘' 과 함께
  /// 붙을 수 있다 — 오늘 공연이라도 문 열기 두 시간 전까지는 이게 안 뜬다.
  static const entryOpen = '입장 진행 중';

  static const noDate = '일시 미정';
  static const empty = '등록된 공연이 없어요';
  static const emptyForKeyword = '검색 결과가 없어요';

  /// 고른 필터에 걸리는 공연이 없을 때. 서버에 공연이 없는 것과 다르다 —
  /// 운영자는 필터를 되돌리기만 하면 된다.
  static const emptyForFilter = '이 조건에 맞는 공연이 없어요';

  /// 필터 칩. 뒤에 개수가 붙는다('오늘 진행 1').
  static const filterAll = '전체';
  static const filterToday = '오늘 진행';
  static const filterUpcoming = '예정 공연';

  /// 칩에 적는 '이름 개수'. 개수를 괄호로 감싸지 않는다 — 칩이 좁아 괄호까지
  /// 넣으면 글자가 줄어든다.
  static String filterChip(String label, int count) => '$label $count';

  /// 화면 읽기 프로그램용. 카드 하나를 한 문장으로 읽어 준다.
  static String tileSemantics(String title, String venueName, String when) =>
      '$title. $venueName. $when';
}
