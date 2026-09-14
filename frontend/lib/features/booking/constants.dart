/// 예매 흐름(구역 선택 · 좌석 선택)의 값과 문구.
class BookingConstants {
  BookingConstants._();

  /// 공연 번호를 모른 채 예매 화면이 열렸을 때 대신 쓰는 공연.
  ///
  /// 정상 흐름에서는 쓰이지 않는다. 홈에서 공연을 누르면 서버가 준 공연 번호가
  /// 상세를 거쳐 여기까지 따라온다. 딥링크나 화면 단위 테스트처럼 흐름 밖에서
  /// 열렸을 때만 이 값으로 떨어져 화면이 비어 보이지 않게 한다.
  ///
  /// 공연 상세 API 연동(S15P21D206-175)이 붙어 공연 번호가 늘 확실해지면
  /// 이 상수를 지운다.
  static const fallbackConcertId = 1;

  /// 좌석을 잡아 두는 시간. 백엔드 `SeatServiceImpl.HOLD_DURATION` 과 같아야 한다.
  ///
  /// 서버가 만료 시각을 내려주는데도 이 값을 두는 이유는 `SeatHold.remainingFrom`
  /// 주석에 있다 — 기기 시계가 서버와 어긋나면 만료 시각을 그대로 쓸 수 없다.
  static const holdDuration = Duration(minutes: 5);

  /// 가짜 API 의 응답 지연. 실제 서버처럼 로딩 상태가 보이게 한다.
  static const mockLatency = Duration(milliseconds: 400);
}

/// 예매 흐름에서 쓰는 문구.
class BookingStrings {
  BookingStrings._();

  /// 서버 응답을 JSON 으로 읽지 못했을 때. 프록시가 HTML 을 준 경우 등.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 잡으려는 순간 남이 먼저 가져갔을 때(409).
  ///
  /// **예매 가능한(초록) 자리를 눌러 결제로 넘어가려던 경우다.** 화면에는 빈
  /// 자리로 보였는데 요청이 오가는 사이에 다른 사람이 채 간 것이라, 눌린
  /// 이유를 알려 줄 자리가 여기밖에 없다.
  ///
  /// 이미 회색인 자리를 누른 것과는 다르다. 그쪽은 아무 말도 하지 않는다 —
  /// 고를 수 없다는 것이 색으로 이미 보이기 때문이다.
  static const seatTaken = '이미 선점된 좌석입니다.';

  /// 선점하려는데 로그인 상태가 아닐 때(401).
  static const loginRequired = '로그인이 필요해요.';

  /// 매진 구역을 눌렀을 때. 구역명이 모음으로 끝나면 '은' 이 틀리므로
  /// 조사가 필요 없는 형태로 쓴다.
  static String zoneSoldOut(String zoneName) =>
      '$zoneName 구역은 매진됐어요. 다른 구역을 골라주세요.';

  static const refreshed = '좌석 정보를 새로 불러왔어요.';
}
