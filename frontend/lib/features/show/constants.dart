import 'package:flutter/physics.dart';

import '../../core/utils/formatters.dart';

/// 공연 상세 화면 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
class ShowDetailMetrics {
  ShowDetailMetrics._();

  /// 좌우 여백. 홈과 같은 값이어야 홈에서 넘어올 때 글의 왼쪽 끝이 안 튄다.
  static const horizontalPadding = 16.0;

  /// 상단 포스터 칸의 비율(가로/세로). 정사각은 세로로 긴 포스터를 통째로 넣고도
  /// (`PosterStage`) 제목·장소·일시가 첫 화면에 함께 보이는 선이다.
  static const posterAspectRatio = 1.0;

  /// 포스터 위아래 여백. 포스터가 칸 높이를 거의 다 쓰되 모서리에 붙지는
  /// 않을 만큼만 띄운다. 남는 좌우는 `PosterStage` 가 흐린 배경으로 메운다.
  static const posterVerticalInset = 14.0;

  /// 섹션 사이 간격.
  static const sectionGap = 26.0;

  /// 섹션 제목과 내용 사이 간격.
  static const sectionTitleGap = 12.0;

  static const badgeRadius = 4.0;
  static const cardRadius = 8.0;

  /// 포스터와 제목 묶음 사이.
  static const summaryTopGap = 14.0;

  /// 제목과 장소·일시 줄 사이.
  static const summaryLineGap = 8.0;

  static const artistAvatarSize = 56.0;
  static const artistGap = 20.0;
  static const artistNameGap = 8.0;

  /// 상세 안내 이미지 사이 간격.
  static const noticeImageGap = 12.0;

  /// 기본 안내 문구의 줄 사이. 이미지 사이보다 좁다 — 네 줄이 한 덩어리의
  /// 규정으로 읽혀야 한다.
  static const noticeLineGap = 8.0;

  /// 기본 안내 문구의 글줄 높이.
  static const noticeLineHeight = 1.5;

  /// 하단 바의 안내 문구와 버튼 사이.
  static const bottomBarGap = 10.0;

  /// 하단 바에 버튼이 둘 설 때(예매 + 양도 마켓 알림) 그 둘 사이. 문구와
  /// 버튼 사이보다 좁다 — 버튼 둘은 같은 묶음으로 읽혀야 한다.
  static const bottomBarActionGap = 8.0;

  /// 펼친 하단 바 위쪽 손잡이 줄의 높이.
  static const bottomBarHandleHeight = 28.0;

  /// 접힌 바가 펼친 바의 몇 분의 일을 남기는가.
  static const bottomBarCollapsedFraction = 1 / 3;

  /// 접힌 바 손잡이 줄의 최소 높이. 버튼 하나가 겨우 서는 공연(잠긴 버튼만)은
  /// 1/3 이 손가락 하나보다 얇아진다.
  static const bottomBarCollapsedMinHeight = 48.0;

  /// 하단 바 위쪽 모서리 둥글기.
  static const bottomBarRadius = 16.0;

  /// 하단 바를 놓았을 때 제자리로 가는 스프링. 감쇠비 1 이라 튕겨 넘치지 않고
  /// 빠르게 붙는다 — 넘치면 펼친 끝에서 바가 한 번 들렸다 내려앉아 보인다.
  static final bottomBarSpring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 420,
  );

  /// 손을 뗄 때 이보다 빠르게(px/s) 밀었으면 멈춘 위치와 상관없이 민 방향으로
  /// 접거나 편다.
  static const bottomBarFlingVelocity = 300.0;

  /// 안내 스낵바와 하단 바 사이 틈. 스낵바는 이 화면의 바 높이만큼 띄워
  /// 올린다(`_snackBarBottomMargin`) — 바를 `Scaffold.bottomNavigationBar`
  /// 가 아니라 본문 안에 그려서 Flutter 가 대신 올려 주지 않는다.
  static const snackBarGap = 12.0;

  /// 안내 문구 앞 시계 아이콘 크기.
  static const countdownIconSize = 15.0;

  /// 본문 맨 아래 여백. 하단 바는 Scaffold 가 본문에서 빼 주지만, 마지막
  /// 문단이 경계선에 딱 붙으면 잘린 것처럼 보인다.
  static const contentBottomGap = 24.0;

  /// 카운트다운으로 보여 주는 범위. 이 밖은 오픈 일시를 그대로 적는다 —
  /// `1152:23:14` 는 언제인지 읽히지 않는다.
  static const countdownWindow = Duration(hours: 24);

  /// 남은 시간을 다시 계산하는 주기.
  static const countdownTick = Duration(seconds: 1);

  /// 가짜 API 의 응답 지연. 실제 서버처럼 로딩 상태가 보이게 한다.
  static const mockLatency = Duration(milliseconds: 400);
}

/// 공연 상세 화면 문구.
class ShowDetailStrings {
  ShowDetailStrings._();

  static const appBarTitle = '공연 상세';

  /// 공연을 받아 오는 동안 뼈대에 붙이는 안내. 화면에 글자로 뜨지는 않고
  /// 스크린 리더가 읽는다.
  static const loading = '공연을 불러오는 중이에요.';

  /// 서버 응답을 JSON 으로 읽지 못했을 때. 프록시가 HTML 을 준 경우 등.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 상단 바 하트. 찜 여부에 따라 둘 중 하나가 붙는다.
  static const favoriteAction = '찜하기';
  static const unfavoriteAction = '찜 해제';

  /// 시안에는 '좌석별 가격' 이지만 서버에 좌석 등급이 하나뿐이라 구역별로 낸다.
  static const zonePriceSection = '구역별 가격';
  static const artistSection = '아티스트';
  static const noticeSection = 'NOTICE';

  static const noticeImageLoading = '안내 이미지를 불러오는 중이에요.';
  static const noticeImageError = '안내 이미지를 불러오지 못했어요.';

  /// 안내 이미지가 없는 공연에 대신 적는 문구. 서비스 전체 규정이라 서버가 아닌 앱이 든다.
  /// 고칠 때 함께 움직여야 하는 곳: 예매 마감은 서버 `Concert.BOOKING_CUTOFF_HOURS`,
  /// 양도 등록가 상한은 서버 `ListingService` 의 정가 이하 검증, 캡처 QR 은
  /// `TicketStrings.qrCaptureNotice`, 취소·환불은 `TicketStrings.cancelConfirmBody`.
  static const defaultNoticeLines = [
    '예매는 공연 시작 2시간 전에 마감돼요.',
    '입장은 티켓 QR로만 할 수 있어요. 캡처한 화면은 입장할 수 없어요.',
    '티켓 양도는 앱 안에서만 할 수 있고, 등록가는 정가를 넘을 수 없어요.',
    '예매를 취소하면 티켓이 회수되고 결제 금액이 전액 환불돼요.',
  ];

  /// 상태 뱃지. 오픈 전후로 갈린다.
  static const upcomingBadge = '오픈 예정';
  static const onSaleBadge = '예매중';

  static const bookAction = '예매하러 가기';

  /// 오픈 알림 버튼. 찜과는 다른 신청이다 — 백엔드가 알림 신청(`CONCERT_OPEN`)을
  /// 찜과 별개로 들고 있어 하나를 풀어도 다른 하나는 그대로다. 그래서 문구에 찜을 안 적는다.
  static const notifyAction = '오픈 알림 받기';
  static const unnotifyAction = '오픈 알림 해제하기';

  /// 양도 마켓 알림 버튼. 새 양도 매물이 올라오면 알려 준다(백엔드 `MARKET_LISTING`).
  /// 오픈 알림과 따로 신청하고 따로 푼다. 예매 중인 공연에만 세운다 — 끝난 공연에는
  /// 사고팔 표가 없고, 오픈 전에는 아직 아무도 표가 없어 올라올 매물이 없다.
  static const marketAlarmAction = '양도 마켓 알림 받기';
  static const marketAlarmOffAction = '양도 마켓 알림 해제하기';

  /// 하단 바 손잡이의 스크린리더 이름. 누르면 일어날 일을 말한다.
  static const collapseBottomBar = '예매 버튼 접기';
  static const expandBottomBar = '예매 버튼 펼치기';

  /// 알림 버튼을 눌렀을 때의 안내. 종류마다 켠 말과 끈 말이 따로 있다 —
  /// 버튼이 둘이라 '알림을 신청했어요' 로 뭉치면 어느 쪽을 켰는지 알 수 없다.
  static const openAlarmOn = '오픈 알림을 신청했어요. 예매가 열리기 전에 알려드릴게요.';
  static const openAlarmOff = '오픈 알림을 껐어요.';
  static const marketAlarmOn = '양도 마켓 알림을 신청했어요. 새 매물이 올라오면 알려드릴게요.';
  static const marketAlarmOff = '양도 마켓 알림을 껐어요.';

  /// 로그아웃 상태에서 알림 버튼을 눌렀을 때. 찜 하트의 안내와 같은 말투다.
  static const alarmLoginRequired = '로그인하고 알림을 받아 보세요';

  /// 이미 끝난 공연의 하단 바. 버튼은 잠기고 이 문구가 대신 선다.
  ///
  /// 매진에는 붙이지 않는다. 취소표가 돌아올 수 있어 들어가 볼 이유가 있다.
  static const closedNotice = '종료된 공연입니다';
  static const canceledNotice = '취소된 공연입니다';

  /// 공연 시작이 가까워 예매만 닫힌 공연의 하단 바. '종료' 를 돌려쓰면 그날 저녁
  /// 공연을 보러 갈 사람이 공연이 없어진 줄 안다. 마감까지 몇 시간인지는 적지 않는다 —
  /// 그 숫자는 서버가 정하고 응답에도 없어, 여기 적으면 서버가 바꾼 날 거짓말이 된다.
  static const bookingClosedNotice = '예매가 마감되었습니다';

  static String venueLine(String venue) => '공연 장소: $venue';
  static String periodLine(String period) => '일시: $period';

  /// 오픈까지 남은 시간. (예: `오픈까지 남은 시간 00:23:14`)
  static String countdown(Duration remaining) =>
      '오픈까지 남은 시간 ${formatCountdownWithHours(remaining)}';

  /// 하루 넘게 남았을 때. (예: `2026.11.01 14:00 오픈`)
  static String openAt(DateTime at) => '${formatPerformedAt(at)} 오픈';
}
