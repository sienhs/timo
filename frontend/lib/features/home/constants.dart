import '../../core/utils/formatters.dart';
import 'models/refresh_hint.dart';

/// 홈 화면 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
///
/// 섹션이 다섯 개나 되고 카드·아바타가 반복되므로, 크기를 위젯마다 적으면
/// 시안이 조금 바뀔 때 전수 수정해야 한다.
class HomeMetrics {
  HomeMetrics._();

  /// 좌우 여백. 섹션 제목과 카드의 왼쪽 끝이 이 값으로 맞아야 시안처럼
  /// 한 줄로 정렬돼 보인다.
  static const horizontalPadding = 16.0;

  /// 섹션 사이 간격.
  static const sectionGap = 28.0;

  /// 섹션 제목과 내용 사이 간격.
  static const sectionTitleGap = 14.0;

  // 상단 바 (로고 + 검색 입구)
  static const topBarHeight = 56.0;
  static const searchFieldHeight = 40.0;
  static const searchFieldRadius = 20.0;
  static const logoGap = 12.0;

  // 배너 캐러셀
  static const bannerHeight = 160.0;
  static const bannerRadius = 12.0;

  /// 다음 배너가 오른쪽에 살짝 걸쳐 보이게 하는 비율. 1.0 이면 꽉 차서
  /// 옆으로 넘길 수 있다는 걸 알 수 없다.
  static const bannerViewportFraction = 0.92;
  static const bannerGap = 8.0;
  static const bannerIndicatorSize = 6.0;
  static const bannerIndicatorGap = 6.0;

  // 인기 아티스트
  static const artistColumns = 4;
  static const artistAvatarSize = 68.0;
  static const artistRowGap = 18.0;
  static const artistNameGap = 8.0;

  /// 아티스트 칸을 눌렀을 때 생기는 하이라이트의 모서리 반경.
  ///
  /// 원으로 자르면 칸(아바타 + 이름)보다 원이 커서 아바타에서 비어져 나온
  /// 원이 그려진다. 칸 모양대로 덮는 둥근 사각형이 시안에 가깝다.
  static const artistCellRadius = 14.0;

  // 공연 카드 (오픈 임박 · 인기 공연 공용)
  static const showCardWidth = 140.0;
  static const showCardGap = 12.0;

  /// 포스터 비율. 인쇄 포스터와 같은 2:3 이다.
  static const posterAspectRatio = 2 / 3;
  static const posterRadius = 8.0;
  static const badgeRadius = 4.0;
  static const badgeInset = 8.0;
  static const showCardTitleGap = 10.0;

  // 아래로 당겨 새로 고치기
  /// 스피너가 뜨는 위치(뷰포트 위쪽에서의 거리). 안내 줄이 이미 위에서
  /// 자리를 차지하므로 기본값(40)보다 올려 전체 높이를 줄인다.
  static const refreshDisplacement = 24.0;

  /// 당길 때 열리는 안내 줄의 높이. 문구가 두 줄까지 들어간다.
  static const refreshHintHeight = 92.0;

  /// 안내 줄이 열리고 닫히는 시간.
  static const refreshHintTransition = Duration(milliseconds: 220);

  /// 강조 낱말이 한 번 튀어오르는 데 걸리는 시간.
  static const refreshJumpDuration = Duration(milliseconds: 620);

  /// 튀어오르는 높이.
  static const refreshJumpHeight = 10.0;

  /// 가장 높이 올랐을 때 얼마나 커지는지. 0 이면 크기 변화 없이 위아래로만
  /// 움직인다.
  static const refreshJumpScale = 0.08;

  /// 손을 뗀 뒤 안내 줄을 접기까지 기다리는 시간.
  ///
  /// 놓는 순간 바로 접으면, 새로 고침이 시작될 때(스피너가 제자리에 앉은
  /// 뒤) 다시 열려서 문구가 한 번 덜컹거린다. 새로 고침이 시작될지
  /// 아닐지를 이만큼 기다려 보고 결정한다.
  static const refreshHintCollapseGrace = Duration(milliseconds: 350);

  /// 본문 맨 아래 여백. 하단 바 자체는 Scaffold 가 본문에서 빼 주지만,
  /// 가운데 + 버튼은 바 위로 솟아 본문 영역을 덮는다. 마지막 카드가 그
  /// 버튼에 가리지 않도록 이만큼 띄운다.
  static const bottomGap = 40.0;
}

/// 홈 화면 문구. 숫자에서 파생되는 문구는 파생 규칙까지 여기 둔다.
class HomeStrings {
  HomeStrings._();

  static const logo = 'TIMO';
  static const searchHint = '찾으시는 공연이 있나요?';
  static const searchEntry = '공연 검색';

  static const artistSection = '인기 아티스트';
  static const artistMore = '더보기';
  static const ticketOpenSection = '티켓 오픈 임박';
  static const ticketOpenMore = '더보기';
  static const popularSection = '인기 공연';

  /// 시안이 이 섹션만 영문 'More' 로 적혀 있다. 오타로 보고 통일하지 않고
  /// 시안대로 둔다 — 기획 확인 후 [ticketOpenMore] 와 맞추면 된다.
  static const popularMore = 'More';

  /// 검색 화면은 아직 없다. 시안의 검색 바는 두고 안내만 띄운다.
  static const searchNotReady = '공연 검색은 준비 중이에요.';

  /// 아래로 당길 때 보여 주는 문구. 당길 때마다 순서대로 돌아간다 —
  /// 무작위로 뽑으면 같은 문구가 연달아 나와 안 바뀌는 것처럼 보인다.
  static const refreshHints = [
    RefreshHint(before: '어떤 공연이 우리를 ', highlight: '기다리고', after: ' 있을까요?'),
    RefreshHint(before: '새로 열린 ', highlight: '티켓', after: '을 찾고 있어요'),
    RefreshHint(before: '오늘은 어떤 ', highlight: '무대', after: '에 갈까요?'),
    RefreshHint(before: '아직 좋은 자리가 ', highlight: '남아', after: ' 있을지 몰라요'),
  ];

  /// 목록 화면이 아직 없는 '더보기' 를 눌렀을 때.
  static String moreNotReady(String sectionTitle) =>
      '$sectionTitle 목록은 준비 중이에요.';

  /// 아티스트 상세도 아직 없다.
  static String artistNotReady(String name) => '$name 화면은 준비 중이에요.';

  /// 순위 뱃지. (예: `1위`)
  static String rank(int rank) => '$rank위';

  /// 티켓 오픈 시각을 남은 기간에 따라 다르게 읽어 준다.
  ///
  /// 시안에 `오늘 14:00 오픈` · `5일 후 오픈` · `10.25 (금) 오픈` 세 형태가
  /// 섞여 있다. 셋 다 같은 데이터(오픈 일시)에서 나오므로 분기를 여기 한 곳에
  /// 두고, `now` 를 받아 테스트에서 시간을 고정할 수 있게 한다.
  static String ticketOpen(DateTime openAt, {required DateTime now}) {
    final daysLeft = _dayGap(from: now, to: openAt);
    if (daysLeft <= 0) return '오늘 ${formatClock(openAt)} 오픈';
    if (daysLeft <= imminentDays) return '$daysLeft일 후 오픈';
    return '${formatMonthDayWithWeekday(openAt)} 오픈';
  }

  /// `N일 후` 로 읽어 주는 범위. 이 밖은 날짜를 그대로 보여 준다 —
  /// `93일 후 오픈` 은 언제인지 감이 오지 않는다.
  static const imminentDays = 7;

  /// 시각을 버리고 날짜 차이만 센다. `Duration.inDays` 로 세면 23시간 뒤
  /// 내일 오픈이 `0일`(=오늘)로 나온다.
  static int _dayGap({required DateTime from, required DateTime to}) =>
      DateTime(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime(from.year, from.month, from.day)).inDays;
}
