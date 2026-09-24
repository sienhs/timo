/// 예매 흐름(구역 선택 · 좌석 선택)의 값과 문구.
class BookingConstants {
  BookingConstants._();

  /// 공연 번호를 모른 채 예매 화면이 열렸을 때 대신 쓰는 공연. 정상 흐름에서는
  /// 쓰이지 않고, 딥링크나 화면 단위 테스트처럼 흐름 밖에서 열렸을 때만 이 값으로
  /// 떨어져 화면이 비어 보이지 않게 한다.
  static const fallbackConcertId = 1;

  /// 좌석을 잡아 두는 시간. 백엔드 `SeatServiceImpl.HOLD_DURATION` 과 같아야 한다.
  /// 기기 시계가 서버와 어긋날 수 있어 만료 시각 대신 이 값으로 남은 시간을 센다
  /// (`SeatHold.remainingFrom`).
  static const holdDuration = Duration(minutes: 5);

  /// 가짜 API 의 응답 지연. 실제 서버처럼 로딩 상태가 보이게 한다.
  static const mockLatency = Duration(milliseconds: 400);
}

/// 예매 흐름에서 쓰는 문구.
class BookingStrings {
  BookingStrings._();

  /// 서버 응답을 JSON 으로 읽지 못했을 때. 프록시가 HTML 을 준 경우 등.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 예매 가능해 보이던 자리를 잡으려는 순간 남이 먼저 가져갔을 때(409).
  /// 이미 회색인 자리를 누른 경우에는 아무 말도 하지 않는다.
  static const seatTaken = '이미 선점된 좌석입니다.';

  /// 이 공연의 티켓을 이미 가지고 있을 때(409). 자리 문제가 아니라 계정 문제라
  /// "다시 골라주세요" 라고 하면 안 된다.
  static const alreadyReserved = '이미 이 공연의 티켓을 가지고 있어요. 한 공연에 한 장만 살 수 있어요.';

  /// 예매 중인 공연이 아닐 때(409). 오픈 전·매진·종료·취소가 전부 여기로 온다.
  /// 배치도 조회는 공연 상태를 보지 않아 좌석표는 멀쩡히 보인다.
  static const concertNotOnSale = '지금은 예매할 수 있는 공연이 아니에요.';

  /// 선점하려는데 로그인 상태가 아닐 때(401).
  static const loginRequired = '로그인이 필요해요.';

  static const captchaTitle = '보안문자 입력';
  static const captchaGuide = '예매를 계속하려면 아래 문자를 입력해주세요.';
  static const captchaHint = '보안문자';
  static const captchaRefresh = '새 보안문자 받기';
  static const captchaImageLabel = '보안문자 그림';
  static const captchaSubmit = '확인';
  static const captchaClose = '예매 그만두기';

  // 보안문자 실패 문구는 서버 문구 대신 앱이 정한다(백엔드와 합의). 오답·만료는
  // 새 그림이 바로 뜨므로 "다시 입력하라" 는 덧붙이지 않는다.
  static const captchaMismatch = '보안문자가 일치하지 않아요.';
  static const captchaExpired = '보안문자 입력 시간이 지났어요.';
  static const captchaRetype = '보안문자를 다시 입력해주세요.';
  static const captchaTooMany = '잠시 후 다시 시도해주세요.';
  static const captchaUnavailable = '보안문자를 불러올 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 좌석을 고르다 보안문자 통과 기록이 끝났을 때(403). 공연 상세로 돌려보낸다.
  static const captchaSessionExpired = '시간이 지나 예매를 다시 시작해주세요.';

  /// 매진 구역을 눌렀을 때. 구역명이 모음으로 끝나면 '은' 이 틀리므로
  /// 조사가 필요 없는 형태로 쓴다.
  static String zoneSoldOut(String zoneName) =>
      '$zoneName 구역은 매진됐어요. 다른 구역을 골라주세요.';
}
