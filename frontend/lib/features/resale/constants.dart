import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// 양도마켓 화면의 치수·시간 기준.
class ResaleMetrics {
  ResaleMetrics._();

  /// 목록을 한 번에 받아 오는 개수. 서버 최대치(100)를 그대로 쓴다.
  ///
  /// 페이지를 나누지 않는 이유는 내 티켓과 같다. 정렬 탭(인기순·최신등록순)이
  /// 서버에 없는 순서라 앱이 다시 세우는데, 그러려면 어차피 다 받아야 한다.
  static const pageSize = 100;

  /// 남은 시간 표시를 갱신하는 주기.
  static const countdownTick = Duration(seconds: 1);

  /// 체인을 타는 요청에만 따로 두는 응답 대기 시간. 구매·등록·등록 취소다.
  ///
  /// 기본값(`ApiClient` 의 10초)으로는 모자란다. 서버가 온체인 작업이 끝날
  /// 때까지 기다렸다 응답하는데, 그 대기가 최대 30초이기 때문이다(백엔드
  /// `ContractClient` 의 영수증 폴링 1초 x 30회). 10초에 끊으면 앱만 실패로
  /// 돌아서고 서버 일은 그대로 끝나, 산 티켓을 못 샀다고, 올린 매물을 못
  /// 올렸다고 읽는다. 그러고 다시 시도하면 이번엔 409 를 받는다.
  ///
  /// 서버 상한보다 넉넉히 둬서, 끊는 쪽은 언제나 서버이게 한다. 한계일 뿐이라
  /// 응답이 빨리 오면 그만큼 빨리 끝난다.
  ///
  /// 가격 수정은 여기 없다 — 그것만 체인을 타지 않고 DB 만 바꾼다
  /// (백엔드 `ListingService.updatePrice`).
  static const onChainTimeout = Duration(seconds: 40);

  /// 구매 확인 화면에서 본 가격이 유효한 시간.
  ///
  /// 예매의 좌석 선점과는 다르다. **양도 매물에는 선점이 없다** — 확인 화면을
  /// 열어 둔 사이에 남이 사 갈 수 있다. 그런데도 시간을 세는 이유는 화면이 든
  /// 가격이 오래되면 결제가 `expectedPrice` 불일치로 거절되기 때문이다. 그
  /// 거절을 결제 버튼에서 받느니 시간이 지나면 버튼을 잠그고 다시 불러온다.
  static const priceWindow = Duration(minutes: 5);

  /// 가짜 API 의 응답 지연. 실제 서버처럼 로딩 상태가 보이게 한다.
  static const mockLatency = Duration(milliseconds: 400);

  // 목록·카드 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
  static const horizontalPadding = 16.0;
  static const cardRadius = 12.0;
  static const cardGap = 10.0;
  static const cardPadding = 14.0;

  static const posterWidth = 56.0;
  static const posterHeight = 72.0;
  static const posterRadius = 8.0;

  static const buttonHeight = 52.0;
  static const infoIconSize = 14.0;

  /// 고른 카드의 테두리 굵기. 안 고른 카드(1)보다 두껍게 그려, 색을 못 가리는
  /// 눈에도 고른 것이 드러나게 한다.
  static const selectedBorderWidth = 2.0;

  /// 마켓 닫힘 화면 한가운데의 큰 카운트다운 글자 크기.
  static const closedCountdownFontSize = 26.0;

  /// 결제 대기 연출 클립의 비율. 자산이 1280x720 이다.
  static const transferClipAspectRatio = 16 / 9;

  /// 영상을 못 읽었을 때 그 자리를 채우는 마스코트의 크기.
  static const transferMascotSize = 160.0;

  /// 결제 완료 화면 위쪽 원형 포스터의 지름.
  static const completePosterDiameter = 132.0;
}

/// 양도마켓 화면에서 쓰는 문구.
class ResaleStrings {
  ResaleStrings._();

  /// 서버 응답을 JSON 으로 읽지 못했을 때. 프록시가 HTML 을 준 경우 등.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  // 공연 선택
  static const marketTitle = '양도마켓';
  static const searchHint = '찾으시는 공연이 있나요?';
  static const sortPopular = '인기순';
  static const sortDeadline = '마감임박순';
  static const registerAction = '양도 등록하기';

  /// 공연 카드 오른쪽 아래의 매물 수.
  static String listingCount(int count) => '$count 건';

  /// 공연 날짜가 아직 안 정해진 공연. 내 티켓 화면과 같은 문구다.
  static const dateUndecided = '일정 미정';

  static const emptyConcerts = '지금 올라온 매물이 없어요';
  static const emptyListings = '이 공연에 남은 매물이 없어요';
  static const emptyTickets = '양도할 수 있는 티켓이 없어요';

  static String searchEmpty(String keyword) => '\'$keyword\' 와 맞는 공연이 없어요';

  /// 로그인 안 한 채로 들어왔을 때. 마켓은 모든 경로가 인증을 요구한다
  /// (백엔드 `MarketApi` 주석) — `mine` 판정에 요청자가 필요해서다.
  static const loginPrompt = '로그인하고 양도마켓을 이용해 보세요.';

  // 마켓 닫힘
  static const closedTitle = '지금은 마켓이 닫혀 있어요';
  static String closedNextOpen(String time) => '다음 오픈은 $time으로 예정되어 있어요';

  /// 운영 시간 밖 요청을 서버가 거절했을 때(409 `MarketClosedException`).
  /// 열린 채로 보다가 닫힌 뒤 구매를 눌렀을 때 받는다.
  static const marketClosedError = '지금은 마켓이 닫혀 있어요. 오픈 후에 다시 시도해주세요.';

  /// 운영 시간 중에 가격을 바꾸려 했을 때(409 `MarketOpenException`). 거래가
  /// 열려 있는 동안 가격은 고정이다. 화면이 버튼을 감추지만, 닫힌 채로 보다가
  /// 열린 뒤 눌렀으면 받는다.
  static const marketOpenError = '마켓이 열려 있는 동안은 가격을 바꿀 수 없어요. 마감 후에 바꿔주세요.';

  /// 아직 올라오지 않은 매물을 사려 했을 때(409 `ListingNotOpenYetException`).
  /// 목록에는 없지만 번호로는 닿을 수 있어 서버가 구매에서 막는다.
  static const listingNotOpenYetError =
      '아직 마켓에 올라오지 않은 매물이에요. 다음 오픈 시간부터 살 수 있어요.';

  /// 카운트다운은 눈으로만 읽히므로 화면 읽기 프로그램에는 말로 준다.
  static String openRemainingSemantics(String remaining) =>
      '마켓 마감까지 $remaining';
  static String closeRemainingSemantics(String remaining) =>
      '마켓 오픈까지 $remaining';

  // 매물 목록
  static const sortLatest = '최신등록순';
  static const sortLowestPrice = '낮은가격순';

  /// 매물 줄의 둘째 칸. 어느 회차의 티켓인지.
  static String roundLabel(String performedAt) => '$performedAt 회차';

  /// 정가 대비 할인율. 등록가는 정가 이하라 늘 0 이하다.
  static String discountRate(int rate) => '-$rate%';

  // 구매 확인
  static const purchaseTitle = '양도 티켓 구매';
  static const faceValueLabel = '정가';
  static const discountLabel = '할인가';
  static const totalLabel = 'TOTAL';
  static const purchaseAction = '결제하기';

  /// [ResaleMetrics.priceWindow] 가 바뀌면 문구의 분 수도 함께 바뀐다.
  static String get purchaseWarning =>
      '${ResaleMetrics.priceWindow.inMinutes}분안에 결제하지 않으면 자리가 넘어가요!';

  static String purchaseActionWithRemaining(String remaining) =>
      '$purchaseAction (남은 시간 $remaining)';

  /// 가격을 확인한 지 오래됐을 때. 결제 버튼 자리를 다시 불러오기로 바꾼다.
  static const priceExpired = '가격을 확인한 지 오래됐어요';
  static const priceExpiredAction = '다시 불러오기';

  /// 매물이 이미 팔렸거나 취소됐을 때. 상세는 200 으로 오고 상태로만 알 수 있다.
  static const listingClosed = '이미 팔렸거나 내려간 매물이에요';

  /// 내가 올린 매물. 서버도 409 로 막지만(`CannotBuyOwnListingException`)
  /// 버튼을 잠그고 이유를 적는 쪽이 낫다.
  static const ownListing = '내가 등록한 매물이에요';

  /// 목록에서의 내 매물 칩. 구매 화면의 [ownListing] 과 달리 **누르면 무엇이
  /// 되는지**까지 적는다 — "내가 등록한 매물이에요" 만 있으면 못 사는 줄이라는
  /// 뜻으로만 읽히고, 그 자리에서 내릴 수 있다는 것을 알 길이 없다.
  static const ownListingDelist = '내 매물 · 눌러서 등록 취소';

  /// 온체인 체결이 실패했을 때(`TransferFailedException`). 서버 문구는 재시도만
  /// 권하는데, 잔액 부족이면 다시 시도해도 같다. 무엇을 보고 와야 하는지 적는다.
  static const transferFailedError = '결제하지 못했어요. 잔액이 모자라거나 매물 상태가 바뀌었을 수 있어요';

  /// 지갑 잔액이 매물가보다 적을 때. 서버도 막지만 온체인 revert 를 가리지
  /// 않고 `TransferFailedException` 하나로 묶어 "잠시 후 다시 시도해 주세요"
  /// 라고 답한다 — 충전하러 가야 하는 사람을 재시도로 보내는 셈이라, 앱이
  /// 먼저 잠그고 이유를 적는다.
  static const insufficientBalance = '잔액이 부족해요';

  // 결제 대기 연출
  static const transferringTitle = '티켓을 옮기는 중이에요';
  static const transferringSubtitle = '잠시만 기다려 주세요';
  static const transferringSemantics = '티켓을 옮기는 중입니다. 잠시만 기다려 주세요.';

  // 결제 완료
  static const completeTitle = '결제가 완료됐어요';
  static const transferringBadge = '티켓 양도 중';
  static const transferredBadge = '티켓 양도 완료';
  static const transferFailedBadge = '티켓 양도 실패';
  /// 체결 응답이 오면 양도는 이미 끝나 있다(서버 `PurchaseService`). 예전에는
  /// "1~2분이 걸릴 수 있어요" 라고 기다리게 했는데, 이제 기다릴 것이 없다.
  static const transferDescription =
      '티켓이 내 티켓함으로 옮겨졌어요.\n공연 당일 이 티켓으로 입장할 수 있어요.';

  /// 온체인 전송이 실패했을 때. 시안에 없는 상태다(서버 `TradeStatus.FAILED`).
  /// 무슨 일이 되돌려지는지는 정산 규칙이 정해지지 않아 단정하지 않는다.
  static const transferFailedDescription = '티켓을 옮기지 못했어요.\n확인 후 알림으로 알려드릴게요.';

  static const viewTicketLabel = '티켓 보러 가기';
  static const goHomeLabel = '홈으로';

  static const concertLabel = '공연명';
  static const performedAtLabel = '일시';

  /// 값은 좌석이 오면 `A구역 9열 6번`, 아직 안 오면 구역명이다. 어느 쪽이든
  /// 자리를 가리키는 값이라 라벨은 `좌석` 하나로 둔다.
  static const seatLabel = '좌석';
  static const paidAmountLabel = '결제 금액';

  // 양도 등록
  static const registerTitle = '양도 등록';
  static const registerNext = '다음으로';
  static const registerSubmit = '마켓에 등록하기';

  /// 등록 직후. 매물은 등록 즉시 마켓에 올라간다(서버 `market.hours.listing-delay-enabled`
  /// 가 꺼져 있다). 마켓이 닫힌 시간이면 그 사실은 마켓 화면이 따로 말한다.
  static const registerSucceeded = '마켓에 등록했어요';

  static const priceSectionTitle = '판매 가격';
  static const priceHint = '정가 이하만 등록할 수 있어요';
  static const priceOverFace = '정가보다 높은 가격으로는 설정할 수 없어요';
  static const priceUnit = coinUnit;
  static const priceFieldLabel = '판매 가격 입력';
  static const priceSliderLabel = '판매 가격 조절';
  static const sliderMinLabel = '0 $coinUnit';

  static String faceValueOf(String price) => '정가 $price';

  // 가격 수정. 내 티켓의 양도 목록 탭이 여는 바텀시트다.
  static const editPriceTitle = '가격 수정';
  static const editPriceSubmit = '가격 수정하기';

  /// 시트 제목 아래 한 줄. 무엇을 얼마에서 바꾸는지 짚어 준다.
  static String editPriceCurrent(String price) => '지금 등록가 $price';
}

/// 양도 진행 상태 배지의 색.
///
/// 지금은 이 도메인만 쓰므로 도메인 안에 둔다. 다른 화면이 같은 이유로
/// (양도 진행 상태를 알리려고) 쓰게 되면 [AppColors] 로 승격한다. 결제 도메인이
/// `PaymentColors` 를 자기 안에 둔 것과 같은 판단이다.
///
/// 배지는 색만으로 상태를 가르지 않는다 — 글자('티켓 양도 중' · '티켓 양도 완료')와
/// 아이콘이 함께 바뀐다. 색은 거들 뿐이다.
class ResaleColors {
  ResaleColors._();

  /// 양도 중. 브랜드 초록을 쓰지 않는다 — 초록은 이 앱에서 '끝났다'는 신호라
  /// 진행 중에 쓰면 완료와 구분이 안 간다.
  static const transferringBackground = Color(0xFFEDE9FB);
  static const transferringForeground = Color(0xFF5B4BC4);

  /// 양도 완료. 옅은 브랜드 초록 바탕에 진한 초록 글자다.
  static const transferredBackground = AppColors.seatAvailable;
  static const transferredForeground = AppColors.primaryPressed;

  /// 양도 실패. [AppColors.accent] 는 옅은 바탕 위 작은 글자로 쓰기에 대비가
  /// 모자라(3:1 남짓) 한 단계 어두운 붉은색을 따로 둔다.
  static const failedBackground = Color(0xFFFDECEA);
  static const failedForeground = Color(0xFFC5372C);

  /// 내가 올린 매물 표시. 상태가 아니라 '내 것'이라는 구분이라 무채색이다.
  static const mineBackground = AppColors.surfaceMuted;
  static const mineForeground = AppColors.textSecondary;
}
