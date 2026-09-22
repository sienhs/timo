import '../../core/utils/formatters.dart';

/// 공연 상세 화면 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
class ShowDetailMetrics {
  ShowDetailMetrics._();

  /// 좌우 여백. 홈과 같은 값이어야 홈에서 넘어올 때 글의 왼쪽 끝이 안 튄다.
  static const horizontalPadding = 16.0;

  /// 상단 포스터 칸의 비율(가로/세로).
  ///
  /// 시안은 2.5:1 로 납작했고 한때 16:9 였는데, 둘 다 포스터를 잘라 쓰는
  /// 비율이라 세로로 긴 실제 포스터를 넣으면 눈 한쪽만 확대됐다. 반대로
  /// 포스터 원본 비율(2:3)에 맞추면 포스터가 첫 화면을 다 차지해 제목·가격이
  /// 스크롤 밖으로 밀린다. 정사각은 포스터를 통째로 넣고도(`PosterStage`)
  /// 제목·장소·일시가 함께 보이는 선이다.
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

  /// 하단 바의 안내 문구와 버튼 사이.
  static const bottomBarGap = 10.0;

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

  /// 서버 응답을 JSON 으로 읽지 못했을 때. 프록시가 HTML 을 준 경우 등.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 상단 바 하트. 찜 여부에 따라 둘 중 하나가 붙는다.
  static const favoriteAction = '찜하기';
  static const unfavoriteAction = '찜 해제';

  /// 시안에는 '좌석별 가격' 이지만 구역별로 낸다. 서버에 좌석 등급이 하나뿐이라
  /// 금액이 갈리는 단위가 구역이다(`ZonePrice` 주석 참고).
  static const zonePriceSection = '구역별 가격';
  static const artistSection = '아티스트';
  static const noticeSection = 'NOTICE';

  static const noticeImageLoading = '안내 이미지를 불러오는 중이에요.';
  static const noticeImageError = '안내 이미지를 불러오지 못했어요.';

  /// 상태 뱃지. 오픈 전후로 갈린다.
  ///
  /// 시안에는 오픈된 공연에도 `오픈 예정` 뱃지가 그려져 있으나 시안 실수로
  /// 본다 — 두 상태가 같은 뱃지를 달면 뱃지가 상태를 나타내지 못한다.
  static const upcomingBadge = '오픈 예정';
  static const onSaleBadge = '예매중';

  static const bookAction = '예매하러 가기';

  /// 오픈 알림 버튼. 알림은 서버가 **그 공연을 찜한 회원**에게 보낸다
  /// (백엔드 `ConcertOpenSweep` — 7일 전·하루 전·1시간 전). 따로 신청할 곳이
  /// 없어 이 버튼이 찜을 그대로 켜고 끈다. 문구에 둘을 같이 적는 이유도
  /// 그래서다 — `오픈 알림 받기` 만 적으면 눌렀을 때 찜 목록에 들어가는 것이
  /// 설명되지 않고, 상단 하트가 같이 채워지는 것도 오작동으로 읽힌다.
  static const notifyAction = '오픈 알림 및 찜하기';
  static const unnotifyAction = '오픈 알림 및 찜 해제';

  /// 버튼을 눌러 찜이 실제로 바뀌었을 때의 안내. 로그인 안내·실패는 찜 공통
  /// 동작(`toggleFavoriteShow`)이 따로 알린다.
  static const openAlarmOn = '오픈 알림을 신청했어요. 예매가 열리기 전에 알려드릴게요.';
  static const openAlarmOff = '오픈 알림을 껐어요.';

  /// 이미 끝난 공연의 하단 바. 버튼은 잠기고 이 문구가 대신 선다.
  ///
  /// 매진에는 붙이지 않는다. 취소표가 돌아올 수 있어 들어가 볼 이유가 있다.
  static const closedNotice = '종료된 공연입니다';
  static const canceledNotice = '취소된 공연입니다';

  /// 공연 시작이 가까워 예매만 닫힌 공연의 하단 바.
  ///
  /// `종료된 공연입니다` 를 돌려쓰지 않는다. 마감은 공연 시작 몇 시간 전부터
  /// 걸리는데, 그날 저녁 공연을 보러 갈 사람이 상세를 열었을 때 '종료' 가
  /// 붙으면 공연이 없어진 줄 안다.
  ///
  /// 마감까지 몇 시간인지는 적지 않는다. 그 숫자는 서버가 정하고 응답에 담겨
  /// 오지도 않아, 여기 적으면 서버가 바꾼 날 조용히 거짓말이 된다.
  static const bookingClosedNotice = '예매가 마감되었습니다';

  static String venueLine(String venue) => '공연 장소: $venue';
  static String periodLine(String period) => '일시: $period';

  /// 오픈까지 남은 시간. (예: `오픈까지 남은 시간 00:23:14`)
  static String countdown(Duration remaining) =>
      '오픈까지 남은 시간 ${formatCountdownWithHours(remaining)}';

  /// 하루 넘게 남았을 때. (예: `2026.11.01 14:00 오픈`)
  static String openAt(DateTime at) => '${formatPerformedAt(at)} 오픈';
}
