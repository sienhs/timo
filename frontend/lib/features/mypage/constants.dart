import '../../core/utils/formatters.dart';

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

  // 내 버섯 카드
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

  // 버섯 충전 화면
  /// 상단 바 아래 첫 카드까지의 여백. 마이페이지 인사말 자리와 같은 값이다.
  static const chargeTopGap = 20.0;

  /// 금액 칸 격자. 시안이 2열 × 3행이다.
  static const presetColumns = 2;
  static const presetGap = 12.0;
  static const presetHeight = 48.0;
  static const presetRadius = 8.0;

  /// 선택된 칸의 체크와 금액 사이 간격. 둘은 한 덩어리로 가운데 정렬되므로,
  /// 고르면 금액이 이 간격과 체크 폭의 절반만큼 왼쪽으로 밀린다.
  static const presetCheckSize = 18.0;
  static const presetCheckGap = 6.0;

  /// 칸 안쪽 좌우 여백. 체크가 테두리에 붙지 않게 띄운다.
  static const presetHorizontalPadding = 12.0;

  /// 고를 때 테두리·배경이 바뀌고 체크가 자리를 넓히며 나타나는 시간.
  /// 더 길면 다음 칸을 고를 때 앞 칸이 아직 접히는 중이라 굼떠 보인다.
  static const presetSelectTransition = Duration(milliseconds: 180);

  /// 카드 제목 → 안내 한 줄 → 금액 격자 순서의 간격.
  static const chargeGuideTopGap = 6.0;
  static const presetGridTopGap = 14.0;

  /// 금액 격자 → '직접 입력' 라벨 → 입력칸.
  static const directInputTopGap = 16.0;
  static const directInputLabelGap = 8.0;

  /// 입력칸 안 `MSR` 앞의 세로 구분선.
  static const unitDividerHeight = 16.0;
  static const unitDividerGap = 10.0;

  /// 입력칸 → 구분선 → 요약 두 줄.
  static const chargeSummaryTopGap = 16.0;
  static const chargeSummaryRowGap = 10.0;

  /// 하단 고정 버튼 둘레 여백.
  static const chargeSubmitPadding = 16.0;

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

  /// 코인 이름은 앱 전체에서 **'버섯'** 하나다(사용자 결정, S15P21D206-168). 전에는
  /// 이 카드가 `Mushroom`, 빠른 메뉴가 `코인 충전` 이라 한 서비스에 이름이 셋이었다.
  static const walletTitle = '내 버섯';

  /// 코인 단위. 서비스 결제 수단은 이 코인 하나다(요구사항 #20). 값은 공용
  /// 포맷터의 [coinUnit] 하나만 본다 — 티켓 환불 금액도 같은 단위를 쓴다.
  static const currencyUnit = coinUnit;

  /// 환율 안내. 충전은 1 MSR = 1원 고정이다.
  static const exchangeRate = '1$coinUnit = 1원';

  static const charge = '충전하기';

  // 버섯 충전 화면. 제목·버튼은 시안 문구 그대로다.
  static const chargeTitle = '버섯 충전';
  static const chargeSubmit = '버섯 충전하기';

  static const chargeAmountTitle = '충전할 금액';
  static const chargeAmountGuide = '추가할 금액을 선택해 주세요.';
  static const directInput = '직접 입력';

  /// 아무것도 안 친 입력칸에 흐리게 뜨는 글자.
  static const chargeAmountHint = '0';

  static const chargeAmountLabel = '추가할 금액';
  static const balanceAfterCharge = '추가 후 잔액';

  /// 금액 + 단위. (예: `10,000 MSR`)
  static String withUnit(String formatted) => '$formatted $currencyUnit';

  /// 보낼 수 없는 금액일 때 입력칸 아래 문구.
  static String chargeBelowMin(String formatted) =>
      '최소 ${withUnit(formatted)} 부터 충전할 수 있어요.';
  static String chargeAboveMax(String formatted) =>
      '한 번에 최대 ${withUnit(formatted)} 까지 충전할 수 있어요.';

  /// 충전에 성공했을 때. 돌아가는 화면에서 뜬다.
  static String chargeSucceeded(String formatted) =>
      '${withUnit(formatted)} 을 충전했어요.';

  /// 로그인 안 한 채로 충전 화면에 들어왔을 때.
  static const chargeLoginPrompt = '로그인하고 버섯을 충전해 보세요.';

  static const historyTitle = '사용 내역';
  static const seeAllHistory = '전체 내역 보기';

  /// 걸러 본 종류에 해당하는 내역이 없을 때.
  static const noTransactions = '아직 내역이 없어요.';

  /// 내역 한 줄의 잔액. (예: `잔액 23,400`)
  static String balanceAfter(String formatted) => '잔액 $formatted';

  /// 로그인 안 한 상태의 안내.
  static const loginPrompt = '로그인하고 내 버섯을 확인해 보세요.';

  /// 화면이 아직 없는 버튼을 눌렀을 때.
  static String notReady(String label) => '$label 화면은 준비 중이에요.';

  /// 서버 응답이 JSON 객체가 아닐 때(프록시 오류 등) 화면에 보여 줄 문구.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';
}
