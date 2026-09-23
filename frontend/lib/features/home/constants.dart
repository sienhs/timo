import 'dart:math' as math;
import 'dart:ui' show Size;

import '../../core/utils/formatters.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/timo_logo.dart';
import 'models/refresh_hint.dart';

/// 홈 화면 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
class HomeMetrics {
  HomeMetrics._();

  /// 좌우 여백. 섹션 제목과 카드의 왼쪽 끝을 이 값으로 맞춘다.
  static const horizontalPadding = 16.0;

  /// 섹션 사이 간격.
  static const sectionGap = 28.0;

  /// 섹션 제목과 내용 사이 간격.
  static const sectionTitleGap = 14.0;

  // 상단 바 (로고 + 검색 입구)
  static const topBarHeight = 56.0;
  static const searchFieldHeight = AppMetrics.searchMinHeight;
  static const searchFieldRadius = AppMetrics.controlRadius;
  static const logoGap = 12.0;

  /// 상단 바 로고 높이. 로그인 헤더의 로고와 같다.
  static const logoHeight = TimoLogo.defaultHeight;

  // 배너 캐러셀
  /// 배너로 올리는 공연 수. 인기 공연 응답의 앞에서부터 이만큼 쓴다.
  static const bannerCount = 3;
  static const bannerRadius = 12.0;

  /// 배너 한 장의 비율(가로/세로). 정사각이 세로 포스터를 자르지 않으면서
  /// 배너가 화면 절반을 넘지 않는 선이다. 좌우 빈 자리는 `PosterStage` 가 메운다.
  static const bannerAspectRatio = 1.0;

  /// 배너가 차지할 수 있는 화면 높이의 최대 비율. 세로로 짧은 기기에서 첫
  /// 화면이 배너로만 차지 않게 한다.
  static const bannerMaxHeightFraction = 0.45;

  /// 배너 포스터의 위아래 여백. 아래에 제목 묶음이 얹히므로 상세보다 좁다.
  static const bannerPosterInset = 10.0;

  /// 배너 제목 묶음의 좌·하단 여백과 줄 간격.
  static const bannerTextInset = 18.0;
  static const bannerTextGap = 6.0;

  /// 화면 크기에 맞춘 배너 높이. 카드 폭([bannerViewportFraction] 에서
  /// 좌우 여백을 뺀 값)에 [bannerAspectRatio] 를 적용하되,
  /// [bannerMaxHeightFraction] 을 넘지 않게 한다.
  static double bannerHeightOf(Size screen) {
    final cardWidth = screen.width * bannerViewportFraction - bannerGap;
    return math.min(
      cardWidth / bannerAspectRatio,
      screen.height * bannerMaxHeightFraction,
    );
  }

  /// 다음 배너가 오른쪽에 살짝 걸쳐 보이게 하는 비율. 1.0 이면 꽉 찬다.
  static const bannerViewportFraction = 0.92;
  static const bannerGap = 8.0;
  static const bannerIndicatorSize = 6.0;
  static const bannerIndicatorGap = 6.0;

  // 인기 아티스트
  static const artistColumns = 4;
  static const artistAvatarSize = 68.0;
  static const artistRowGap = 18.0;
  static const artistNameGap = 8.0;

  /// 아티스트 칸(아바타 + 이름)을 눌렀을 때 생기는 하이라이트의 모서리 반경.
  static const artistCellRadius = 14.0;

  // 공연 카드 (오픈 예정 · 인기 공연 공용)
  static const showCardWidth = 140.0;
  static const showCardGap = 12.0;

  /// 포스터 비율. 인쇄 포스터와 같은 2:3 이다.
  static const posterAspectRatio = 2 / 3;
  static const posterRadius = 8.0;
  static const badgeRadius = 4.0;
  static const badgeInset = 8.0;
  static const showCardTitleGap = 10.0;

  // 아래로 당겨 새로 고치기
  /// 스피너가 뜨는 위치(뷰포트 위쪽에서의 거리). 안내 줄이 위에 있어 기본값(40)보다 올린다.
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

  /// 손을 뗀 뒤 안내 줄을 접기까지 기다리는 시간. 바로 접으면 새로 고침이
  /// 시작될 때 다시 열려 문구가 덜컹거린다.
  static const refreshHintCollapseGrace = Duration(milliseconds: 350);

  /// 본문 맨 아래 여백. 하단 바 가운데 + 버튼이 본문을 덮으므로 마지막 카드가
  /// 가리지 않게 띄운다.
  static const bottomGap = 40.0;

  // 카테고리 화면
  /// 장르 격자. 3열 × 2행이다.
  static const categoryColumns = 3;
  static const categoryGap = 12.0;
  static const categoryVerticalPadding = 20.0;
  static const categoryCardRadius = AppMetrics.cardRadius;

  /// 칸 비율(가로/세로). 정사각이라 폰 폭이 달라도 칸 모양이 같다.
  static const categoryCardAspectRatio = 1.0;

  /// 장르 아이콘 크기. 빠른 메뉴 패널의 아이콘과 같다.
  static const categoryIconSize = 28.0;
  static const categoryLabelGap = 8.0;

  /// 공연이 없는 장르 칸의 오른쪽 위 뱃지.
  static const categoryBadgeInset = 8.0;
  static const categoryBadgeHorizontalPadding = 6.0;
  static const categoryBadgeVerticalPadding = 2.0;

  /// 격자 아래 안내 한 줄까지의 간격.
  static const categoryNoteGap = 20.0;

  // 서버 요청
  /// 카드 한 줄에 받아 오는 공연 수. 나머지는 '더보기' 가 맡는다.
  static const showRowSize = 10;

  /// 검색 결과 한 번에 받아 오는 수. 서버 기본값과 같다.
  static const searchPageSize = 20;

  /// 더보기로 들어가는 목록 화면이 한 번에 받아 오는 수. 서버가 허용하는
  /// 최대치다. 검색과 탭 거르기를 앱에서 하므로 한 번에 다 받아 둔다.
  static const showListPageSize = 100;

  /// 홈 인기 아티스트 격자에 받아 오는 수. 두 줄을 꽉 채우는 칸 수다.
  static const popularArtistGridSize = artistColumns * 2;

  /// 검색 화면 추천 검색어 한 줄에 받아 오는 수. 넘기지 않는 한 줄이라 칸 수와
  /// 같다.
  static const recommendedArtistRowSize = artistColumns;

  /// 관련 아티스트 한 줄에 받아 오는 수. 가로로 넘기는 한 줄이라 공연 검색
  /// 결과만큼 받을 필요가 없다.
  static const relatedArtistPageSize = 10;

  /// 실시간 인기 검색어 줄 수. 시안이 10위까지다.
  static const trendingCount = 10;

  /// 목 API 응답 지연. 실제 서버처럼 잠깐 기다려야 로딩 상태와 새로 고침
  /// 안내 문구가 눈에 보인다. 안내 문구의 튀어오르기 연출이 끝나기 전에
  /// 응답이 오면 문구가 도중에 접힌다.
  static const mockLatency = Duration(milliseconds: 1200);

  /// 불러오는 동안 그리는 빈 카드 수. 폰 폭(360)에 카드 두 장 반이 보인다.
  static const skeletonCardCount = 3;

  /// 뼈대에 그리는 탭 글자 한 개의 폭. '예매 가능 12' 정도를 덮는 길이다.
  static const skeletonTabLabelWidth = 64.0;

  /// 뼈대에 그리는 날짜 칩의 폭. '전체 기간' 칩과 비슷한 길이다.
  static const skeletonFilterChipWidth = 104.0;

  /// 뼈대에 그리는 섹션 제목 줄의 폭.
  static const skeletonSectionTitleWidth = 120.0;

  /// 뼈대에 그리는 순위 숫자의 폭. 실제 자리([trendingRankWidth])보다 좁다 —
  /// 한 자리 숫자가 들어갈 만큼만 칠하고 나머지는 여백으로 둔다.
  static const skeletonRankWidth = 12.0;

  /// 뼈대에 그리는 검색어 줄의 두 가지 길이.
  static const skeletonKeywordWideWidth = 160.0;
  static const skeletonKeywordNarrowWidth = 110.0;

  // 검색 화면
  /// 상단 바(뒤로가기 · 로고)와 검색 필드 사이, 필드와 첫 섹션 사이 간격.
  static const searchFieldTopGap = 4.0;
  static const searchFieldBottomGap = 24.0;

  /// 최근 검색어 칩. 가로로 넘기는 한 줄이다.
  static const recentChipHeight = 36.0;
  static const recentChipGap = 8.0;
  static const recentChipHorizontalPadding = 14.0;
  static const recentChipIconSize = 16.0;
  static const recentChipIconGap = 4.0;

  /// 기기에 남기는 최근 검색어 수. 넘치면 오래된 것부터 떨어진다.
  static const recentSearchLimit = 10;

  /// 실시간 인기 검색어 줄.
  static const trendingRowHeight = 48.0;
  static const trendingRankWidth = 32.0;
  static const trendingChangeIconSize = 20.0;

  /// 순위 숫자를 강조색으로 찍는 상위 범위. 시안은 1~3위만 색이 다르다.
  static const trendingHighlightRanks = 3;

  /// 목록 카드 높이. 검색 결과와 더보기 목록 화면이 함께 쓴다. 포스터를 자르지
  /// 않으면서 한 화면에 세 건은 보이는 선이다.
  static const searchCardHeight = 200.0;

  /// 검색 결과 카드 포스터의 위아래 여백. 배너와 같다.
  static const searchCardPosterInset = bannerPosterInset;
  static const searchCardGap = 12.0;

  /// 목록 카드 왼쪽 위 뱃지의 여백. 오른쪽 위 하트([favoriteButtonInset] +
  /// 버튼 안쪽 여백)와 눈높이를 맞춘다.
  static const searchCardBadgeInset = 12.0;
  static const favoriteIconSize = 24.0;
  static const favoriteButtonInset = 4.0;

  /// 처음 보여 주는 결과 카드 수. 넘치면 더보기가 나머지를 펼친다.
  static const searchPreviewCount = 3;

  /// 관련 아티스트 칸 폭. 아바타보다 조금 넓어 이름이 들어간다.
  static const relatedArtistCellWidth = 88.0;

  /// 관련 아티스트 아바타 원 테두리에 걸친 하트. 아바타(68) 지름의 40% 쯤으로
  /// 잡아 걸쳐 있다는 게 한눈에 보이게 한다. 터치 영역은 아이콘보다 넓게.
  static const artistFavoriteIconSize = 28.0;
  static const artistFavoriteButtonSize = 36.0;

  /// 하트 버튼이 아바타 정사각형 밖으로 나가는 거리. 하트 중심이 원 테두리
  /// (오른쪽 아래 45°)에 오도록 잡은 값이다.
  static const artistFavoriteOverhang = 8.0;

  // 공연 전체 화면의 날짜·정렬 필터 줄
  /// 탭 줄과 목록 사이에 끼는 필터 줄의 위아래 여백.
  static const filterBarVerticalPadding = 10.0;

  /// 날짜 칩. 찜 화면의 필터 칩과 같은 높이다.
  static const filterChipHeight = 36.0;
  static const filterChipHorizontalPadding = 12.0;
  static const filterChipIconSize = 16.0;
  static const filterChipIconGap = 6.0;

  /// 날짜 칩 오른쪽의 해제(×) 버튼. 칩 높이 안에서 누를 수 있을 만큼만.
  static const filterChipClearSize = 28.0;

  /// 정렬 메뉴 옆 화살표.
  static const sortIconSize = 18.0;

  // 날짜 선택 시트
  /// 시트가 차지하는 화면 높이 비율. 달력이 두 달쯤 보이면서 뒤 화면이 살짝
  /// 남는 선이다.
  static const dateSheetHeightFraction = 0.88;
  static const sheetRadius = 16.0;
  static const sheetHandleWidth = 36.0;
  static const sheetHandleHeight = 4.0;
  static const sheetHandleTopGap = 10.0;
  static const sheetHorizontalPadding = 16.0;
  static const sheetTitleGap = 4.0;
  static const sheetSectionGap = 16.0;

  /// 시트 맨 아래 초기화·적용 줄의 위아래 여백과 둘 사이 간격.
  static const sheetActionVerticalPadding = 12.0;
  static const sheetActionGap = 12.0;

  /// 빠른 선택 칩(전체 · 이번 주말 · …). 날짜 칩보다 한 단계 작다.
  static const presetChipHeight = 32.0;
  static const presetChipGap = 8.0;
  static const presetChipHorizontalPadding = 14.0;

  // 달력
  /// 날짜 칸 높이. 터치 최소 크기(44)다. 폭은 화면을 7 등분한다.
  static const calendarCellHeight = 44.0;

  /// 시작·끝 날짜에 그리는 원의 지름. 칸보다 작아 위아래로 숨이 트인다.
  static const calendarDayCircleSize = 36.0;

  /// 공연이 있는 날 아래 점.
  static const calendarDotSize = 4.0;
  static const calendarDotGap = 2.0;

  /// 달 제목과 요일 줄, 요일 줄과 첫 주, 달과 달 사이 간격.
  static const calendarMonthTitleGap = 12.0;
  static const calendarWeekdayGap = 8.0;
  static const calendarMonthGap = 24.0;

  /// 달력이 보여 주는 달 수의 아래·위 한계. 공연이 없어도 석 달은 펼치고,
  /// 아무리 먼 공연이 있어도 열두 달을 넘기지 않는다.
  static const calendarMinMonths = 3;
  static const calendarMaxMonths = 12;

  /// 시작·끝 원과 구간 띠가 나타나는 시간. 동작 줄이기 설정이면 0 이다.
  static const calendarSelectDuration = Duration(milliseconds: 150);
}

/// 홈 화면 문구. 숫자에서 파생되는 문구는 파생 규칙까지 여기 둔다.
class HomeStrings {
  HomeStrings._();

  static const searchHint = '찾으시는 공연이 있나요?';
  static const searchEntry = '공연 검색';

  static const artistSection = '인기 아티스트';
  static const ticketOpenSection = '티켓 오픈 예정';
  static const ticketOpenMore = '더보기';
  static const popularSection = '인기 공연';

  /// 섹션마다 같은 말이지만 상수는 따로 둔다(한쪽만 바뀌는 날이 올 수 있다).
  static const popularMore = '더보기';

  // 검색 화면
  static const back = '뒤로';
  static const clearSearch = '검색어 지우기';
  static const recentSection = '최근 검색어';
  static const clearRecent = '전체 삭제';
  static String removeRecent(String keyword) => '$keyword 삭제';
  static const recommendedSection = '추천 검색어';
  static const trendingSection = '실시간 인기 검색어';
  static const trendingUp = '상승';
  static const trendingDown = '하락';
  static const resultSection = '오픈 예정 / 예매중';
  static const resultMore = '더보기';
  static const relatedArtistSection = '관련 아티스트';

  /// 하트 버튼. 찜 여부에 따라 둘 중 하나가 붙는다.
  static const favorite = '찜';
  static const unfavorite = '찜 해제';

  /// 검색어를 누르면 그 말로 검색한다는 스크린 리더용 라벨. (예: `아이유 검색`)
  static String searchFor(String keyword) => '$keyword 검색';

  /// 인기 검색어 집계 시각. 앱의 다른 일시와 같은 표기(0 을 붙인다)를 쓴다.
  static String trendingAsOf(DateTime asOf) => '${formatPerformedAt(asOf)} 기준';

  /// 결과가 없을 때. 검색어를 되비춰 준다.
  static String searchEmpty(String keyword) => "'$keyword' 에 맞는 공연이 없어요.";

  /// 서버가 빈 목록을 줬을 때 카드 줄 자리에 적는다.
  static const noShows = '아직 보여 드릴 공연이 없어요.';

  /// 공연 시작일이 정해지지 않은 공연의 기간 문구.
  static const periodUndecided = '일정 미정';

  /// 서버 응답이 JSON 목록이 아닐 때(프록시 오류 등) 화면에 보여 줄 문구.
  static const unreadableResponse = '서버 응답을 읽을 수 없어요. 잠시 후 다시 시도해주세요.';

  /// 불러오는 동안 스켈레톤에 달아 두는 스크린 리더용 라벨.
  static const loading = '공연을 불러오는 중이에요.';

  /// 아래로 당길 때 보여 주는 문구. 당길 때마다 순서대로 돌아간다 —
  /// 무작위로 뽑으면 같은 문구가 연달아 나와 안 바뀌는 것처럼 보인다.
  static const refreshHints = [
    RefreshHint(before: '어떤 공연이 우리를 ', highlight: '기다리고', after: ' 있을까요?'),
    RefreshHint(before: '새로 열린 ', highlight: '티켓', after: '을 찾고 있어요'),
    RefreshHint(before: '오늘은 어떤 ', highlight: '무대', after: '에 갈까요?'),
    RefreshHint(before: '아직 좋은 자리가 ', highlight: '남아', after: ' 있을지 몰라요'),
  ];

  // 더보기로 들어가는 목록 화면
  /// 오픈 예정 공연 전체. 홈의 섹션 제목을 그대로 쓴다 — 더보기를 눌러 들어온
  /// 화면의 제목이 눌렀던 섹션과 다르면 다른 곳에 온 것처럼 읽힌다.
  static const openSoonListTitle = ticketOpenSection;

  /// 공연 전체 조회.
  static const allShowsListTitle = '공연 전체';

  /// 전체 조회의 탭. 예매로 이어지는 공연만 보는 쪽이 기본이다.
  static const bookableTab = '예매 가능';
  static const closedTab = '예매 마감';
  static const allTab = '모두 보기';

  /// 목록 화면의 검색 칸. 받아 둔 목록을 그 자리에서 거른다.
  static const listSearchHint = '공연명으로 찾기';

  /// 목록이 비었을 때. 검색 중이면 검색어를 되비춰 준다.
  static const emptyOpenSoonList = '오픈 예정인 공연이 없어요.';
  static const emptyAllShowsList = '아직 등록된 공연이 없어요.';
  static const emptyBookableList = '지금 예매할 수 있는 공연이 없어요.';
  static const emptyClosedList = '예매가 마감된 공연이 없어요.';

  // 카테고리 화면
  /// 빠른 메뉴의 항목 이름과 같다. 눌렀던 이름과 화면 제목이 다르면 다른
  /// 곳에 온 것처럼 읽힌다.
  static const categoryTitle = '카테고리';

  /// 공연이 없는 장르 칸에 다는 뱃지.
  static const categoryNotReadyBadge = '준비 중';

  /// 공연이 없는 장르를 눌렀을 때.
  static String categoryNotReady(String label) => '$label 공연은 준비 중이에요.';

  /// 격자 아래 한 줄. 다섯 칸이 흐린 이유를 미리 알려 준다.
  static const categoryNote = '지금은 콘서트만 예매할 수 있어요.';

  /// 인기 공연 카드의 예매 상태 뱃지. 살 수 있는 둘(예매중 · 오픈예정)만
  /// 색으로 가르고 마감은 색 없이 둔다.
  static const bookingOnSale = '예매중';
  static const bookingUpcoming = '오픈예정';
  static const bookingClosed = '예매 마감';

  /// 티켓 오픈 시각을 남은 기간에 따라 `오늘 14시` · `5일 후` · `10.25 (금)`
  /// 세 형태로 읽어 준다. `now` 를 받아 테스트에서 시간을 고정할 수 있다.
  static String ticketOpen(DateTime openAt, {required DateTime now}) {
    final daysLeft = _dayGap(from: now, to: openAt);
    if (daysLeft <= 0) return '오늘 ${_clockInWords(openAt)} 오픈';
    if (daysLeft <= imminentDays) return '$daysLeft일 후 오픈';
    return '${formatMonthDayWithWeekday(openAt)} 오픈';
  }

  /// 당일 오픈 시각을 말로 읽는다. (예: `11시 12분`, 정각이면 `14시`)
  /// `11:12` 표기는 공연 일시에도 쓰여 오늘 오픈 옆에 붙으면 공연 시각으로 읽힌다.
  static String _clockInWords(DateTime at) =>
      at.minute == 0 ? '${at.hour}시' : '${at.hour}시 ${at.minute}분';

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

  // 공연 전체 화면의 날짜·정렬 필터
  /// 날짜 칩의 기본 문구. 기간을 고르면 `09.23 ~ 10.05` 로 바뀐다.
  static const dateFilterAll = '전체 기간';

  /// 날짜 칩 오른쪽 × 의 스크린 리더용 라벨.
  static const dateFilterClear = '기간 해제';

  /// 정렬 메뉴 툴팁.
  static const sortMenu = '정렬';

  static const sortPopular = '인기순';
  static const sortStartDate = '공연일 빠른 순';
  static const sortOpenSoon = '오픈 임박순';

  /// 날짜를 골랐는데 그 기간에 공연이 없을 때.
  static const emptyInDateRange = '이 기간엔 공연이 없어요.';

  // 날짜 선택 시트
  static const dateSheetTitle = '날짜 선택';

  /// 아직 아무 날도 고르지 않았을 때 제목 아래 한 줄.
  static const dateSheetHint = '가고 싶은 날을 골라 주세요';

  /// 시작일만 고른 상태. 끝을 고르지 않고 적용하면 하루짜리 기간이 된다.
  static const dateSheetPickEnd = '마지막 날도 고르면 기간이 돼요';

  static const dateSheetReset = '초기화';
  static const dateSheetApplyAll = '전체 공연 보기';
  static String dateSheetApply(int count) => '공연 $count건 보기';

  static const presetAll = '전체';
  static const presetThisWeekend = '이번 주말';
  static const presetThisMonth = '이번 달';
  static const presetNextMonth = '다음 달';

  /// 달력 요일 줄. 일요일부터 시작한다.
  static const calendarWeekdays = ['일', '월', '화', '수', '목', '금', '토'];

  /// 달 제목. (예: `2026년 10월`)
  static String calendarMonth(DateTime month) =>
      '${month.year}년 ${month.month}월';

  /// 날짜 칸의 스크린 리더용 라벨. 공연이 있으면 몇 건인지까지 읽는다 —
  /// 점 하나로는 색을 못 보는 사람에게 전달되지 않는다.
  static String calendarDay(DateTime day, {required int showCount}) {
    final date = '${day.month}월 ${day.day}일';
    return showCount > 0 ? '$date, 공연 $showCount건' : date;
  }
}
