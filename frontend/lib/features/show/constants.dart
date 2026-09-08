import '../../core/utils/formatters.dart';

/// 공연 상세 화면 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
class ShowDetailMetrics {
  ShowDetailMetrics._();

  /// 좌우 여백. 홈과 같은 값이어야 홈에서 넘어올 때 글의 왼쪽 끝이 안 튄다.
  static const horizontalPadding = 16.0;

  /// 상단 포스터 비율(가로/세로).
  ///
  /// 시안은 2.5:1 로 더 납작했는데, 실제 포스터를 넣으니 눈 한쪽만 확대돼
  /// 무슨 공연인지 알 수 없었다. 반대로 포스터 원본 비율(2:3)에 맞추면
  /// 포스터가 첫 화면을 다 차지해 제목·가격이 스크롤 밖으로 밀린다.
  /// 16:9 는 포스터가 사람 얼굴로 읽히면서 제목·장소·일시까지 함께 보인다.
  static const posterAspectRatio = 16 / 9;

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

  /// 안내 문단 사이 간격.
  static const noticeParagraphGap = 12.0;

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
}

/// 공연 상세 화면 문구.
class ShowDetailStrings {
  ShowDetailStrings._();

  static const appBarTitle = '공연 상세';

  static const favoriteAction = '찜하기';

  static const seatPriceSection = '좌석별 가격';
  static const artistSection = '아티스트';
  static const noticeSection = 'NOTICE';

  /// 상태 뱃지. 오픈 전후로 갈린다.
  ///
  /// 시안에는 오픈된 공연에도 `오픈 예정` 뱃지가 그려져 있으나 시안 실수로
  /// 본다 — 두 상태가 같은 뱃지를 달면 뱃지가 상태를 나타내지 못한다.
  static const upcomingBadge = '오픈 예정';
  static const onSaleBadge = '예매중';

  static const notifyAction = '오픈 알림 받기';
  static const bookAction = '예매하러 가기';

  /// 아직 화면이 없는 조작부. 시안대로 두고 안내만 띄운다.
  static const favoriteNotReady = '찜하기는 준비 중이에요.';
  static const notifyNotReady = '오픈 알림은 준비 중이에요.';

  static String venueLine(String venue) => '공연 장소: $venue';
  static String periodLine(String period) => '일시: $period';

  /// 오픈까지 남은 시간. (예: `오픈까지 남은 시간 00:23:14`)
  static String countdown(Duration remaining) =>
      '오픈까지 남은 시간 ${formatCountdownWithHours(remaining)}';

  /// 하루 넘게 남았을 때. (예: `2026.11.01 14:00 오픈`)
  static String openAt(DateTime at) => '${formatPerformedAt(at)} 오픈';
}
