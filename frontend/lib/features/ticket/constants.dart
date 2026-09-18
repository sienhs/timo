/// 내 티켓 화면의 치수·시간 기준.
class TicketMetrics {
  TicketMetrics._();

  /// 목록을 한 번에 받아 오는 개수. 서버 최대치(100)를 그대로 쓴다.
  ///
  /// 페이지를 나누지 않는 이유: 예정/지난을 가르는 기준(공연 날짜)이 서버에
  /// 없어 어차피 다 받아야 나눌 수 있다. 티켓이 100장 넘는 사람이 나오면
  /// 서버에 필터를 요청한다.
  static const pageSize = 100;

  /// 예매를 취소할 수 있는 마지막 시점. 공연 시작 이 시간 전까지다.
  /// 백엔드 `ReservationStubController.CANCEL_DEADLINE_HOURS` 와 같아야 한다.
  static const cancelDeadline = Duration(hours: 24);

  /// 입장 QR 이 열리는 시각. 공연 시작 이만큼 전부터.
  ///
  /// 백엔드 `EntryPassService.ENTRY_OPENS_BEFORE_START` 와 같아야 한다. 앱이
  /// 더 일찍 열면 버튼은 눌리는데 서버가 409 로 거절해 "왜 안 되지" 만 남는다.
  static const qrOpensBefore = Duration(hours: 2);

  /// 입장 QR 이 닫히는 시각. 공연 시작 이만큼 뒤까지.
  ///
  /// 백엔드 `EntryPassService.ENTRY_CLOSES_AFTER_START` 와 같아야 한다. 종료
  /// 시각이 아니라 시작 시각 기준인 것도 서버와 같다 — 여러 날 공연이면 종료일이
  /// 며칠 뒤라 그동안 내내 열린 채가 된다.
  static const qrClosesAfter = Duration(hours: 6);

  /// 검색 칸을 띄우기 시작하는 티켓 수.
  ///
  /// 시안에는 티켓 2장짜리 목록 위에도 검색 칸이 있다. 두 줄을 눈으로 훑는
  /// 편이 빠른 자리에 검색을 두면 화면만 좁아진다.
  static const searchVisibleFrom = 5;

  /// 가짜 API 의 응답 지연. 실제 서버처럼 로딩 상태가 보이게 한다.
  static const mockLatency = Duration(milliseconds: 400);

  /// 가짜 API 가 주문 상세를 몇 번째 물었을 때 발행을 끝내는가.
  ///
  /// 결제 완료 화면이 몇 초마다 묻는 것을 서버 없이 볼 수 있게, 처음 몇 번은
  /// "발행 중" 으로 답하고 그 뒤에 끝낸다. 실제 서버는 체인 트랜잭션 두 개가
  /// 확정되기까지 몇 초가 걸린다.
  static const mockIssueAfterPolls = 2;

  /// 가짜 API 가 내주는 입장 QR 의 수명. 서버 기본값(`entry-pass.ttl`, 30초)과
  /// 같다. 실제 서버는 응답에 수명을 실어 주므로 앱 어디에도 이 값을 박지 않는다.
  static const mockEntryPassLifetime = Duration(seconds: 30);

  // 목록·카드 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
  static const horizontalPadding = 16.0;
  static const cardRadius = 12.0;
  static const cardPadding = 14.0;
  static const cardGap = 12.0;

  /// 카드 왼쪽 포스터. 폭은 고정이고 **높이는 오른쪽 글 묶음(제목 + 정보 줄)에
  /// 맞춰 늘어난다**(사용자 피드백 — 아래가 좌석 줄과 나란해야 한다). 그래서
  /// [posterHeight] 는 실제 카드가 아니라 뼈대 카드(`TicketListSkeleton`)가 쓰는
  /// 대표값이다. 제목이 한 줄일 때의 글 묶음 높이에 맞췄다.
  static const posterWidth = 68.0;
  static const posterHeight = 102.0;
  static const posterRadius = 8.0;

  /// 입장 QR 화면 오른쪽 위 포스터. 목록 카드보다 조금 크다.
  static const qrPosterWidth = 96.0;
  static const qrPosterHeight = 128.0;

  /// 남은 시간이 이 안쪽이면 카운트다운을 경고색으로 바꾼다.
  ///
  /// 5초는 검표기가 QR 을 읽고 서버가 판정하기까지 걸리는 시간(보통 1~2초)에
  /// 여유를 둔 값이다. 이보다 적게 남았으면 내밀지 말고 새로 받는 편이 낫다.
  static const qrWarningThreshold = Duration(seconds: 5);

  /// 만료된 QR 을 덮는 흰색의 불투명도. 검은 칸이 연한 회색으로 보일 만큼
  /// 덮되, 아래에 QR 이 있었다는 것은 알아볼 수 있게 남긴다.
  static const qrExpiredOverlayOpacity = 0.8;

  /// 만료된 QR 가운데의 새로고침 아이콘 크기. 손가락으로 바로 누를 만큼.
  static const qrRefreshIconSize = 36.0;

  static const buttonHeight = 44.0;
  static const infoIconSize = 15.0;

  /// 불러오는 동안 세워 두는 뼈대 카드 수. 첫 화면을 채울 만큼만.
  static const skeletonCardCount = 3;
}

/// 내 티켓 화면에서 쓰는 문구.
class TicketStrings {
  TicketStrings._();

  /// 서버 응답을 JSON 으로 읽지 못했을 때. 프록시가 HTML 을 준 경우 등.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 공연까지 남은 날 배지. 오늘이면 `D-DAY`.
  ///
  /// 시안은 날짜가 다른 두 카드에 모두 `D-Day` 가 붙어 있는데, 그대로 두면
  /// 9일 남은 공연과 오늘 공연이 구분되지 않는다.
  static String dday(int days) => days == 0 ? 'D-DAY' : 'D-$days';

  static const screenTitle = '내 티켓';
  static const notifications = '알림';
  static const searchHint = '찾으시는 공연이 있나요?';

  static const tabUpcoming = '예정 공연';
  static const tabPast = '지난 공연';
  static const tabListings = '양도 목록';

  static const enterQr = '입장 QR 보기';
  static const showDetail = '상세정보 보기';
  static const more = '더보기';

  /// 공연 날짜가 아직 안 정해진 공연. 서버가 `startDate` 를 비워 준다.
  static const dateUndecided = '일정 미정';

  /// QR 버튼이 안 열린 카드에 덧붙이는 한 줄. 시안에는 없다.
  ///
  /// 없으면 카드마다 버튼이 다른 이유를 알 수 없다. 첫 카드만 초록 버튼인 것을
  /// 보고 "왜 이 공연만 입장이 되지" 로 읽힌다.
  ///
  /// 시각은 [TicketMetrics.qrOpensBefore] 에서 가져온다. "공연 당일" 이라고
  /// 적어 두면 당일 아침에 눌러 보고 안 열려 의아해한다 — 실제 규칙은 시작
  /// 2시간 전이고, 서버가 그 폭을 바꾸면 문구도 따라가야 한다.
  static String get qrOpensBeforeShow =>
      '입장 QR 은 공연 시작 ${TicketMetrics.qrOpensBefore.inHours}시간 전에 열려요';

  /// 지난 공연 카드의 버튼.
  ///
  /// 시안은 `NFT 소장품 보기` 와 `만들기` 두 종류인데 하나로 합쳤다. 서버가
  /// "이 티켓이 소장품을 만들었는지" 를 알려줄 방법이 아직 없어(티켓 도메인
  /// 자체가 없다) 둘을 가를 근거가 없다. 자리와 크기는 같으므로 나중에 분기를
  /// 넣어도 배치는 그대로다.
  static const createCollectible = 'NFT 소장품 만들기';

  // 티켓을 지금 쓸 수 없는 카드. 시안에 없다. 버튼을 지우고 그 자리에 사정을
  // 적는다. 발행 중·실패·환불은 165번 때 합의했다가 168번에서 서버가 값을 안
  // 준다고 걷어냈고, 서버가 티켓 상태를 주게 되어 되살렸다(S15P21D206-331).
  // 양도 등록 중·입장 완료는 331번에서 새로 정했다(사용자 결정).

  /// 예매 취소로 회수된 티켓.
  static const cancelledNotice = '예매를 취소했어요.';

  /// 발행 중인 티켓의 배지. D-day 자리에 대신 붙는다 — 아직 표가 없는데 남은
  /// 날을 세는 게 앞서 나간다.
  static const issuingBadge = 'NFT 발행 중';

  /// 결제 뒤 온체인 발행이 아직 안 끝난 티켓. 보통 몇 초다.
  static const issuingNotice = '티켓을 만들고 있어요. 잠시 후 다시 확인해주세요.';

  /// 발행이 실패해 서버가 결제 금액을 돌려주는 중.
  static const mintFailedNotice = '발행에 실패했어요. 환불이 진행 중이에요.';

  /// 보상 환불까지 끝난 티켓. "환불됐어요" 만 적으면 예매 취소와 헷갈려 원인을
  /// 붙인다 — 사용자가 한 일이 아니라 발행 실패의 뒷처리다.
  static const refundedNotice = '발행에 실패해 환불됐어요.';

  /// 양도 마켓에 올라가 있는 티켓. 팔리기 전까지 입장·취소가 막힌다. 내리는
  /// 길은 양도 목록 탭에 있어 그리로 안내한다.
  ///
  /// 폰 폭(375)에서 한 줄에 들어가는 길이다. 길면 "있어 / 요." 처럼 낱말
  /// 중간에서 꺾인다(에뮬레이터로 확인).
  static const listedNotice = '양도 등록 중이에요. 취소는 양도 목록 탭에서요.';

  /// 게이트에서 입장 처리가 끝난 티켓. QR 을 다시 받아도 서버가 거절한다.
  static const usedNotice = '입장 완료';

  /// 앱이 모르는 상태가 왔을 때. 서버에 상태가 하나 늘면 나온다.
  ///
  /// 무슨 일인지 단정하지 않는다. 취소인지 다른 무엇인지 앱이 모르는 상황이라,
  /// 아는 만큼만 — 지금 할 수 있는 게 없다는 것만 — 말한다.
  static const unknownStatusNotice = '지금은 이용할 수 없어요.';

  // 빈 목록. 탭마다 할 말이 다르다.
  static const emptyUpcoming = '예정된 공연이 없어요';
  static const emptyUpcomingAction = '공연 보러 가기';
  static const emptyPast = '아직 다녀온 공연이 없어요';

  /// 양도 목록 탭. 내가 올린 매물이 하나도 없을 때 — 팔린 것·내린 것까지 없을 때다.
  static const emptyListings = '등록한 양도 매물이 없어요';

  /// 로그인 안 한 채로 들어왔을 때. 마이페이지·충전 화면의 안내와 같은 꼴이다.
  /// 내 티켓은 서버가 로그인한 회원의 주문만 주므로 로그인 없이는 보여줄 게 없다.
  static const loginPrompt = '로그인하고 내 티켓을 확인해 보세요.';

  /// 검색 결과가 없을 때.
  static String searchEmpty(String keyword) => '\'$keyword\' 와 맞는 공연이 없어요';

  /// 아직 화면이 없는 곳을 눌렀을 때.
  static String notReady(String label) => '$label 은(는) 준비 중이에요.';

  // 입장 QR 화면.
  static const qrScreenTitle = '입장 QR';
  static const qrRemaining = '남은 시간';

  /// QR 이 몇 초 동안 쓸 수 있는지. 숫자는 서버가 응답에 실어 준 수명이다 —
  /// 앱에 30 을 박아 두면 서버가 수명을 바꿨을 때 문구가 거짓말을 한다.
  static String qrValidFor(int seconds) => 'QR 은 $seconds초 동안 유효해요';

  /// 수명이 다한 뒤. 흐린 QR 만으로는 무엇을 해야 하는지 알 수 없어 한 줄 붙인다.
  static const qrExpiredNotice = 'QR 이 만료됐어요. 새로고침을 눌러 다시 받아 주세요';

  /// 만료된 QR 가운데의 새로고침 버튼. 화면 읽기 프로그램이 읽는 이름이다.
  static const qrRefresh = 'QR 새로 받기';
  static const qrCaptureNotice =
      '화면을 캡처한 QR 은 입장할 수 없어요.\n입장 시 이 화면을 직접 보여주세요.';

  /// 진행 바는 눈으로만 읽히므로 화면 읽기 프로그램에는 초를 말로 준다.
  static String qrRemainingSemantics(int seconds) => '$qrRemaining $seconds초';

  static const qrDate = '일시';
  static const qrSeat = '좌석';
  static const qrVenue = '장소';

  // 카드 더보기(⋮). 시안에 자리가 없어 카드 오른쪽 위로 뺐다.

  /// 양도마켓의 등록 화면으로 간다. 마켓 첫 화면 아래 버튼과 같은 문구다.
  static const registerListing = '양도 등록하기';

  static const cancelReservation = '예매 취소하기';
  static const cancelConfirmTitle = '예매를 취소할까요?';
  // "같은 자리를 다시 잡을 수는 없어요" 는 뺐다(사용자 결정). 팝업이 길어지고,
  // 취소를 망설이게 하는 정보라기보다 취소 뒤의 사정이라 여기서 할 말이 아니다.
  static const cancelConfirmBody = '취소하면 티켓이 회수되고 결제 금액이 전액 환불돼요.';
  static const cancelConfirmAgree = '예매 취소하기';
  static const cancelConfirmKeep = '그대로 둘게요';

  // 더보기 항목이 막힌 이유. 항목을 비활성으로 두고 아래 붙인다. 항목을 지우면
  // 왜 못 하는지 물어볼 자리가 없다.

  /// 예매 취소: 공연이 코앞이다.
  static const cancelTooLate = '공연 24시간 전까지만 취소할 수 있어요';

  /// 예매 취소: 양도로 받은 티켓. 예매 행이 판 사람 것이라 서버가 404 를 낸다.
  static const cancelNotBooked = '양도로 받은 티켓은 예매 취소를 할 수 없어요';

  /// 예매 취소: 마켓에 올라가 있다. 먼저 내려야 한다.
  static const cancelWhileListed = '양도 등록 중에는 취소할 수 없어요';

  /// 양도 등록: 이미 올라가 있다.
  static const alreadyListed = '이미 양도 등록 중이에요';

  /// 환불 금액. 수수료 없이 정가 전액이다.
  static String refundAmount(String price) => '환불 금액 $price';

  // 양도 목록 카드. 내가 마켓에 올린 매물 하나다.
  static const listingBadge = '판매중';
  static const soldBadge = '판매 완료';

  /// 등록은 됐지만 아직 남에게 안 보이는 매물. 매물은 등록 다음 날 여는 시각에
  /// 올라간다(백엔드 `MarketApi` 주석). `판매중` 대신 붙어, 마켓 목록에 왜 없는지
  /// 카드가 먼저 말한다.
  static const pendingExposureBadge = '노출 대기';

  /// 그 매물이 마켓에 올라가는 시각. (예: `09.16 20:00 마켓 노출`)
  static String exposureAt(String time) => '$time 마켓 노출';
  static const editPrice = '가격 수정';
  static const delist = '등록 취소';

  /// 등록가를 바꾸고 목록을 다시 받은 뒤. 바뀐 숫자만으로는 눈에 잘 안 띄어
  /// 한 줄 알린다(등록 취소는 회색 카드가 남아 따로 알리지 않는다).
  static const priceUpdated = '등록가를 바꿨어요';

  /// 등록가 줄. 결제 수단이 코인이라 단위는 `MSR` 이다(`formatMsr`).
  static String listedPrice(String price) => '$price 등록';

  /// 양도 마감(공연 시작)까지 하루 안쪽일 때. `마감까지 07:31` 처럼 시:분이다.
  ///
  /// 초는 찍지 않는다. 이 화면은 새로 고칠 때만 시각을 다시 재므로 초까지
  /// 찍으면 멈춘 숫자가 된다.
  static String deadlineIn(Duration remaining) {
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    return '마감까지 $hours:$minutes';
  }

  /// 하루 넘게 남았으면 마감 일시를 그대로. 양도 마감은 공연 시작이라 보통
  /// 며칠 남는데, 늘 카운트다운으로 찍으면 `172:31` 처럼 읽히지 않는 숫자가 된다.
  static String deadlineAt(String dateTime) => '양도 마감 $dateTime';

  /// 공연이 이미 시작했거나 일정이 미정이라 더 팔 수 없을 때.
  static const deadlinePassed = '양도 마감';

  // 닫힌 매물. 버튼 자리에 사정을 적는다. 예매 취소한 티켓 카드와 같은 꼴이다.
  static const soldNotice = '판매가 완료됐어요.';
  static const delistedNotice = '등록을 취소했어요.';

  // 양도 등록 취소 팝업. 예매 취소와 같은 틀이라 '그대로 둘게요' 는 함께 쓴다.
  static const delistConfirmTitle = '양도 등록을 취소할까요?';
  // 폰 폭(375)에서 한 줄에 들어가는 길이다. 길면 "돌아와 / 요." 로 꺾인다.
  static const delistConfirmBody = '취소하면 매물이 내려가고 티켓은 다시 내 것으로 돌아와요.';
  static const delistConfirmAgree = '등록 취소하기';

  /// 팝업의 금액 줄. 내리는 것이라 돌아오는 돈은 없고, 얼마에 올려 뒀는지만 짚는다.
  static String listedPriceLabel(String price) => '등록가 $price';
}
