/// 공연 선택 흐름의 치수·문구.
class ConcertMetrics {
  ConcertMetrics._();

  /// 목록 한 줄의 포스터 썸네일. 공연 포스터는 세로가 긴 비율이라 너비를 정하면
  /// 높이가 따라온다.
  static const posterWidth = 56.0;
  static const posterAspectRatio = 3 / 4;
  static const posterRadius = 8.0;

  /// 한 줄의 최소 높이. 장갑 낀 손으로도 눌러야 해서 터치 최소선(44)보다 넉넉하다.
  static const tileMinHeight = 76.0;

  /// 불러오는 동안 깔아 둘 빈 줄의 개수. 폰 한 화면을 덮을 만큼만.
  static const skeletonTileCount = 6;

  /// 한 번에 받아 올 공연 수. 목록에 검색이 붙어 있어 더 받아올 이유가 없고,
  /// 서버 상한(100)이기도 하다.
  static const pageSize = 100;

  /// 검색어를 다 친 것으로 보고 서버에 요청하기까지 기다리는 시간. 한 글자마다
  /// 요청하면 공연장 와이파이에서 앞 요청의 응답이 뒤늦게 도착해 목록이 튄다.
  static const searchDebounce = Duration(milliseconds: 300);

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

  static const noDate = '일시 미정';
  static const empty = '등록된 공연이 없어요';
  static const emptyForKeyword = '검색 결과가 없어요';

  /// 화면 읽기 프로그램용. 줄 하나를 한 문장으로 읽어 준다.
  static String tileSemantics(String title, String venueName, String when) =>
      '$title. $venueName. $when';
}
