import 'dart:math' as math;
import 'dart:ui' show Size;

import '../../core/utils/formatters.dart';
import '../../core/theme/app_metrics.dart';
import '../../core/widgets/timo_logo.dart';
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
  static const searchFieldHeight = AppMetrics.searchMinHeight;
  static const searchFieldRadius = AppMetrics.controlRadius;
  static const logoGap = 12.0;

  /// 상단 바 로고 높이. 로그인 헤더의 로고와 같다.
  static const logoHeight = TimoLogo.defaultHeight;

  // 배너 캐러셀
  /// 배너로 올리는 공연 수. 인기 공연 응답의 앞에서부터 이만큼 쓴다.
  static const bannerCount = 3;
  static const bannerRadius = 12.0;

  /// 배너 한 장의 비율(가로/세로).
  ///
  /// 납작한 배너는 세로 포스터를 심하게 잘라 낸다. 그렇다고 포스터 비율
  /// (2:3)에 가깝게 세우면 배너 하나가 첫 화면을 다 먹는다. 정사각은 포스터를
  /// 통째로 넣으면서도 배너가 화면의 절반을 넘지 않는 선이다 — 좌우에 남는
  /// 자리는 `PosterStage` 가 같은 포스터를 흐리게 깔아 메운다.
  static const bannerAspectRatio = 1.0;

  /// 배너가 차지할 수 있는 화면 높이의 최대 비율. 세로로 짧은 기기에서
  /// [bannerAspectRatio] 를 그대로 지키면 첫 화면이 배너로만 차서, 아래에
  /// 섹션이 더 있다는 걸 알 수 없다.
  static const bannerMaxHeightFraction = 0.45;

  /// 배너 포스터의 위아래 여백. 상세보다 좁다 — 배너는 아래쪽에 제목 묶음이
  /// 얹히므로 포스터가 칸을 더 채우는 편이 낫다.
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

  // 서버 요청
  /// 카드 한 줄에 받아 오는 공연 수. 가로로 넘기는 줄이라 이보다 많이 받아도
  /// 끝까지 넘겨 보는 사람이 없고, '더보기' 가 나머지를 맡는다.
  static const showRowSize = 10;

  /// 검색 결과 한 번에 받아 오는 수. 서버 기본값과 같다.
  static const searchPageSize = 20;

  /// 더보기로 들어가는 목록 화면이 한 번에 받아 오는 수. 서버가 허용하는
  /// 최대치다. 검색과 탭 거르기를 모두 앱에서 하므로 한 번에 다 받아 둔다 —
  /// 글자마다 서버에 다녀오면 늦게 온 앞 글자의 결과가 뒤를 덮는다. 공연이
  /// 이보다 많아지면 그때 아래로 이어 받는 방식을 붙인다.
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

  // 검색 화면
  /// 상단 바(뒤로가기 · 로고)와 검색 필드 사이, 필드와 첫 섹션 사이 간격.
  static const searchFieldTopGap = 4.0;
  static const searchFieldBottomGap = 24.0;
  static const searchFieldIconSize = 20.0;
  static const searchFieldHorizontalPadding = 14.0;
  static const searchFieldIconGap = 8.0;

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

  /// 목록 카드 높이. 검색 결과와 더보기로 들어가는 목록 화면이 함께 쓴다.
  ///
  /// 배너처럼 포스터를 자르지 않고 보여 주되([bannerAspectRatio] 대신 고정
  /// 높이), 한 화면에 결과가 세 건은 보이는 선에서 멈춘다. 목록은 훑어보는
  /// 화면이라 한 건이 자리를 많이 먹으면 무엇이 더 있는지 알 수 없다 —
  /// 더보기 목록은 스무 건이 넘게 이어지므로 특히 그렇다.
  static const searchCardHeight = 200.0;

  /// 검색 결과 카드 포스터의 위아래 여백. 배너와 같다.
  static const searchCardPosterInset = bannerPosterInset;
  static const searchCardGap = 12.0;
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
  /// (오른쪽 아래 45°, 중심에서 34·24 씩 = 58)에 오도록 잡은 값이다 — 원 안에
  /// 넣으면 얼굴을 가리고, 밖에 두면 어느 아티스트의 하트인지 흐려진다. 칸이
  /// 아바타보다 양옆으로 10 넓어 옆 칸을 침범하지 않는다.
  static const artistFavoriteOverhang = 8.0;
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

  /// 시안은 이 섹션만 영문 'More' 였다. 기획 확인 후 한글로 맞췄다 — 같은
  /// 일을 하는 버튼이 섹션마다 다른 말로 불리면 읽는 쪽이 다른 기능인지
  /// 의심한다. 상수는 섹션별로 남겨 둔다(한쪽만 바뀌는 날이 올 수 있다).
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

  /// 인기 검색어 집계 시각. 앱의 다른 일시와 같은 표기(0 을 붙인다)를 쓴다 —
  /// 시안은 `2026.9.4` 로 0 을 뗐지만 한 앱 안에서 표기가 갈릴 이유가 없다.
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
  static const allTab = '모두 보기';

  /// 목록 화면의 검색 칸. 받아 둔 목록을 그 자리에서 거른다.
  static const listSearchHint = '공연명으로 찾기';

  /// 목록이 비었을 때. 검색 중이면 검색어를 되비춰 준다.
  static const emptyOpenSoonList = '오픈 예정인 공연이 없어요.';
  static const emptyAllShowsList = '아직 등록된 공연이 없어요.';
  static const emptyBookableList = '지금 예매할 수 있는 공연이 없어요.';

  /// 순위 뱃지. (예: `1위`)
  static String rank(int rank) => '$rank위';

  /// 티켓 오픈 시각을 남은 기간에 따라 다르게 읽어 준다.
  ///
  /// 시안에 `오늘 14:00 오픈` · `5일 후 오픈` · `10.25 (금) 오픈` 세 형태가
  /// 섞여 있다. 셋 다 같은 데이터(오픈 일시)에서 나오므로 분기를 여기 한 곳에
  /// 두고, `now` 를 받아 테스트에서 시간을 고정할 수 있게 한다.
  static String ticketOpen(DateTime openAt, {required DateTime now}) {
    final daysLeft = _dayGap(from: now, to: openAt);
    if (daysLeft <= 0) return '오늘 ${_clockInWords(openAt)} 오픈';
    if (daysLeft <= imminentDays) return '$daysLeft일 후 오픈';
    return '${formatMonthDayWithWeekday(openAt)} 오픈';
  }

  /// 당일 오픈 시각을 말로 읽는다. (예: `11시 12분`, 정각이면 `14시`)
  ///
  /// 당일에만 이 표기를 쓴다. `11:12` 같은 시계 표기는 기간·공연 일시에도
  /// 쓰여서, 오늘 열린다는 말 옆에 붙으면 공연 시각으로 읽힌다. 정각에 `0분`
  /// 을 붙이지 않는 것은 읽는 대로 적기 위해서다 — 아무도 "열네시 영분" 이라고
  /// 말하지 않는다.
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
}
