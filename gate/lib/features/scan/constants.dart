/// 스캔 흐름의 시간·치수 기준.
class ScanMetrics {
  ScanMetrics._();

  /// 입장 허용 화면이 스스로 닫히는 시간. 다음 사람이 바로 서므로 짧게.
  /// 거절·확인 실패는 운영자가 사유를 읽고 버튼으로 닫는다.
  static const admittedHold = Duration(milliseconds: 1500);

  /// 같은 QR 을 이 시간 안에 다시 읽으면 무시한다. 관람객이 폰을 그대로 들고
  /// 있으면 카메라가 초당 여러 번 같은 코드를 읽어 검증이 중복된다.
  static const duplicateWindow = Duration(seconds: 3);

  /// 결과 화면이 나타나고 사라지는 시간.
  static const resultFade = Duration(milliseconds: 180);

  /// 조준 틀 안을 오가는 스캔 선의 한 왕복.
  static const scanLineSweep = Duration(milliseconds: 1800);

  /// 카메라 화면 폭에 대한 조준 틀의 비율.
  static const viewfinderFraction = 0.68;

  /// 화면 높이에 대한 조준 틀 윗변의 위치. 운영자가 폰을 들었을 때 시선보다
  /// 조금 위에 오도록 가운데보다 올렸다.
  static const viewfinderTopFraction = 0.16;

  /// 조준 틀 아랫변과 안내 패널 사이 간격.
  static const viewfinderToGuideGap = 32.0;

  /// 조준 틀 구멍의 모서리 반경. 꺾쇠가 이 곡선을 따라 굽는다.
  static const viewfinderRadius = 24.0;
  static const viewfinderCornerLength = 36.0;
  static const viewfinderStroke = 4.0;

  /// 스캔 선의 두께와 위아래로 번지는 빛의 높이.
  static const scanLineStroke = 2.0;
  static const scanLineGlow = 28.0;

  /// 스캔 선 한가운데의 점. 선만 있으면 어디를 겨누는지 모호해, 관람객 폰을
  /// 맞출 과녁을 하나 둔다.
  static const scanLineDotRadius = 4.0;

  static const resultIconSize = 148.0;
  static const resultCardRadius = 16.0;

  /// 결과 화면의 작은 알약(‘중복 스캔 감지’·‘TICKET VERIFIED’).
  static const pillRadius = 999.0;

  /// 카메라 위 안내 패널의 모서리.
  static const panelRadius = 16.0;

  /// 헤더(공연명 + 서버 상태)가 차지하는 높이. 기본 앱바(56)로는 상태 칩까지
  /// 세 줄이 안 들어간다.
  static const headerHeight = 88.0;

  /// 서버 상태 칩 앞의 점.
  static const statusDotSize = 8.0;

  /// 하단 집계 막대의 모서리와 바깥 여백.
  static const counterBarRadius = 16.0;
  static const counterBarInset = 16.0;

  static const horizontalPadding = 20.0;

  /// 가짜 API 의 응답 지연.
  static const mockLatency = Duration(milliseconds: 300);
}

/// 팬 앱이 만드는 입장 QR 의 형식. **팬 앱 `EntryPass` 와 같아야 한다.**
///
/// 지금은 팬 앱이 `timo:entry:<예매ID>:<발급초>:<nonce>` 를 직접 만든다. 서버가
/// 서명 토큰을 발급하게 되면 이 형식은 서버 계약으로 옮겨 가고, 앱은 페이로드를
/// 해석하지 않고 그대로 서버에 넘긴다. 그때 이 클래스는 [MockScanApi] 와 함께
/// 지운다.
class EntryPayload {
  EntryPayload._();

  static const prefix = 'timo:entry:';

  /// 발급 후 유효 시간. 팬 앱 `EntryPass.lifetime` 과 같은 값.
  static const lifetime = Duration(seconds: 30);
}

/// 스캔 흐름의 문구.
class ScanStrings {
  ScanStrings._();

  static const appName = 'TIMO 게이트';

  // 스캔 대기
  static const scanHint = 'QR을 사각형 안에 맞춰주세요';
  static const scanDescription = '입장 QR 화면을 직접 보여 달라고 안내해주세요';
  static const verifying = '확인 중…';
  static const torchOn = '손전등 켜기';
  static const torchOff = '손전등 끄기';
  static const changeTarget = '공연 변경';
  static const cameraUnavailable = '카메라를 열 수 없어요';
  static const cameraPermissionDenied =
      '카메라 권한이 없어요.\n설정에서 TIMO 게이트의 카메라 권한을 허용해주세요.';

  // 서버 상태 칩. 와이파이가 아니라 **검표 서버에 닿았는지** 를 말한다 —
  // 게이트에서 문제가 되는 건 언제나 후자다.
  static const serverUnknown = '서버 확인 전';
  static const serverOnline = '실시간 온라인';
  static const serverOffline = '서버 응답 없음';

  // 하단 집계. 앱을 켠 뒤 이 단말이 찍은 것만 센다(서버 집계가 아니다).
  static const tallyTotal = '총 스캔';
  static const tallyAdmitted = '정상 입장';
  static const tallyRejected = '거절/오류';

  // 결과
  static const admitted = '입장 승인 완료';
  static const admittedDetail = '정상 등록된 티켓입니다. 관객 입장을 진행하세요.';
  static const admittedPill = 'TICKET VERIFIED';
  static const rejected = '입장 불가';
  static const undetermined = '확인 실패';
  static const duplicatePill = '중복 스캔 감지';
  static const rejectedGuide = '고객님께 안내소 방문을 권유해 주세요';
  static const undeterminedGuide = '다시 스캔해주세요';
  static const verifiedAt = '검표 완료 시각';
  static const justNow = '방금 전';
  static const confirm = '확인';

  /// 검표 완료 시각 한 줄. (예: `방금 전 (19:02:14)`)
  static String verifiedAtValue(String clock) => '$justNow ($clock)';

  /// 결과 화면을 화면 읽기 프로그램용 한 문장으로.
  static String resultSemantics(String title, String detail) =>
      '$title. $detail';
}
