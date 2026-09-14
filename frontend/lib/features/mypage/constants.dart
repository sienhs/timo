/// 마이페이지 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
class MyPageMetrics {
  MyPageMetrics._();

  static const horizontalPadding = 20.0;

  /// 상단 바(뒤로가기 · 제목 · 알림). 홈 상단 바와 같은 높이다.
  static const topBarHeight = 56.0;
  static const topBarIconSize = 24.0;

  /// 알림 아이콘 위의 미확인 점.
  static const unreadDotSize = 8.0;

  /// 인사말 위·아래 여백.
  static const greetingTopGap = 24.0;
  static const greetingBottomGap = 20.0;

  /// 초록 테두리 카드 (잔액 · 사용 내역 공용).
  static const cardRadius = 14.0;
  static const cardBorderWidth = 1.5;
  static const cardPadding = 16.0;
  static const cardGap = 20.0;

  // 내 Mushroom 카드
  static const walletIconSize = 24.0;
  static const walletTitleGap = 8.0;
  static const balanceTopGap = 14.0;
  static const balanceFontSize = 34.0;
  static const balanceUnitGap = 8.0;
  static const chargeButtonTopGap = 14.0;
  static const chargeButtonHeight = 48.0;
  static const chargeButtonRadius = 8.0;

  // 사용 내역 카드
  static const filterHeight = 28.0;
  static const filterRadius = 6.0;
  static const filterItemHorizontalPadding = 10.0;
  static const filterInset = 2.0;
  static const historyTopGap = 12.0;
  static const transactionVerticalPadding = 12.0;
  static const transactionLineGap = 4.0;
  static const seeAllTopGap = 8.0;

  /// 사용 내역 카드에 보여 주는 최근 건수. 나머지는 '전체 내역 보기' 가 맡는다.
  static const recentTransactionCount = 4;

  /// 불러오는 동안 카드 자리를 지키는 높이. 응답이 오면 내용 높이로 바뀐다.
  static const loadingCardHeight = 160.0;

  /// 본문 맨 아래 여백. 가운데 + 버튼이 바 위로 솟아 본문을 덮으므로 마지막
  /// 버튼이 가리지 않게 띄운다. 홈과 같은 값이다.
  static const bottomGap = 40.0;

  /// 로그아웃 버튼과 위 카드 사이 간격.
  static const logoutTopGap = 28.0;

  /// 목 API 응답 지연. 실제 서버처럼 잠깐 기다려야 로딩 상태가 보인다.
  static const mockLatency = Duration(milliseconds: 600);
}

/// 마이페이지 문구.
class MyPageStrings {
  MyPageStrings._();

  static const title = '마이페이지';
  static const back = '뒤로';
  static const notifications = '알림';

  /// `{닉네임} 님 환영해요!` — 닉네임은 굵게, 나머지는 보통 굵기로 나뉘어
  /// 그려지므로 둘을 따로 둔다.
  static const greetingSuffix = ' 님 환영해요!';

  static const walletTitle = '내 Mushroom';

  /// 코인 단위. 서비스 결제 수단은 이 코인 하나다(요구사항 #20).
  static const currencyUnit = 'MSR';

  /// 환율 안내. 충전은 1 MSR = 1원 고정이다.
  static const exchangeRate = '1MSR = 1원';

  static const charge = '충전하기';

  static const historyTitle = '사용 내역';
  static const seeAllHistory = '전체 내역 보기';

  /// 걸러 본 종류에 해당하는 내역이 없을 때.
  static const noTransactions = '아직 내역이 없어요.';

  /// 내역 한 줄의 잔액. (예: `잔액 23,400`)
  static String balanceAfter(String formatted) => '잔액 $formatted';

  /// 로그인 안 한 상태의 안내.
  static const loginPrompt = '로그인하고 내 Mushroom 을 확인해 보세요.';

  /// 화면이 아직 없는 버튼을 눌렀을 때.
  static String notReady(String label) => '$label 화면은 준비 중이에요.';

  /// 서버 응답이 JSON 객체가 아닐 때(프록시 오류 등) 화면에 보여 줄 문구.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';
}
