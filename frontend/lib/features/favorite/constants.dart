/// 찜리스트 화면 치수. 시안(폰 폭 375 기준)에서 잰 값이다.
class FavoriteMetrics {
  FavoriteMetrics._();

  /// 좌우 여백. 홈·검색과 같은 16 이라 화면을 오갈 때 카드 왼쪽 끝이 맞는다.
  static const horizontalPadding = 16.0;

  /// 탭 아래 검색 칸까지, 검색 칸 아래 필터 줄까지의 간격.
  static const searchFieldTopGap = 16.0;
  static const searchFieldBottomGap = 14.0;
  static const searchFieldHeight = 44.0;
  static const searchFieldRadius = 12.0;
  static const searchFieldIconSize = 20.0;
  static const searchFieldHorizontalPadding = 14.0;
  static const searchFieldIconGap = 8.0;

  /// 판매 상태 필터 칩 줄.
  static const filterChipHeight = 36.0;
  static const filterChipGap = 8.0;
  static const filterChipHorizontalPadding = 16.0;
  static const filterRowBottomGap = 14.0;

  /// '총 N개' 와 정렬 메뉴가 놓인 줄.
  static const summaryRowBottomGap = 10.0;
  static const sortIconSize = 18.0;

  // 공연 카드
  static const showCardRadius = 12.0;
  static const showCardPadding = 12.0;
  static const showCardGap = 10.0;
  static const posterWidth = 64.0;

  /// 포스터 비율. 인쇄 포스터와 같은 2:3 이다.
  static const posterAspectRatio = 2 / 3;
  static const posterRadius = 8.0;
  static const posterGap = 12.0;
  static const cardLineGap = 4.0;
  static const cardMetaIconSize = 14.0;
  static const cardMetaIconGap = 4.0;
  static const statusBadgeRadius = 4.0;

  // 아티스트 줄
  static const artistTileRadius = 12.0;
  static const artistTilePadding = 12.0;
  static const artistTileGap = 10.0;
  static const artistAvatarSize = 64.0;
  static const artistAvatarGap = 14.0;

  /// 하트 버튼. 공연 카드·아티스트 줄 오른쪽 위에 같은 크기로 앉는다.
  static const favoriteIconSize = 24.0;

  /// 목록 맨 아래 안내 문구 위아래 여백.
  static const footerGap = 20.0;

  /// 본문 맨 아래 여백. 하단 바 위로 솟은 원형 버튼이 마지막 카드를 가리지
  /// 않게 띄운다. 검색 화면과 같은 값이다.
  static const bottomGap = 40.0;

  /// 되돌리기 스낵바와 하단 바(원형 버튼 포함) 사이 틈.
  static const snackBarGap = 12.0;

  // 빈 화면
  static const emptyIconSize = 56.0;
  static const emptyTitleGap = 16.0;
  static const emptyBodyGap = 6.0;
  static const emptyActionGap = 24.0;
  static const emptyActionWidth = 160.0;
  static const emptyTopGap = 48.0;
}

/// 찜 API 에 거는 한계값.
class FavoriteLimits {
  FavoriteLimits._();

  /// 한 번에 받아 오는 찜 공연 수. 서버가 허용하는 최대치와 같다.
  ///
  /// 페이지를 더 넘기는 UI 는 두지 않았다. 100개를 넘게 찜한 사람은 최근
  /// 100건만 보인다 — 무한 스크롤은 MVP 범위 밖이고, 그 전에 화면의 필터·정렬이
  /// 기기에 받아 둔 목록을 기준으로 돈다는 점부터 바꿔야 한다.
  static const showPageSize = 100;

  /// 하트를 누르고 서버로 보내기까지 기다리는 시간.
  ///
  /// 하트는 연타된다. 누를 때마다 보내면 요청이 그 수만큼 나가고, 더 나쁜 것은
  /// **응답이 순서대로 오지 않는다는 것이다** — 켰다 끈 두 요청 중 끄기가 먼저
  /// 도착하면 서버에는 찜이 남고 화면에는 빈 하트가 남는다. 그래서 화면만 즉시
  /// 바꾸고, 손이 멈춘 뒤 마지막 의도 하나만 보낸다.
  ///
  /// 300ms 는 연타로 읽히는 간격이다. 더 늘리면 한 번만 누르고 바로 앱을 닫는
  /// 사람의 찜이 나가지 못한다.
  static const toggleDebounce = Duration(milliseconds: 300);
}

/// 찜리스트 화면 문구.
class FavoriteStrings {
  FavoriteStrings._();

  static const appBarTitle = '찜리스트';
  static const back = '뒤로';

  static const showTab = '공연';
  static const artistTab = '아티스트';

  /// 목록을 받아 오는 동안 뼈대에 붙이는 안내. 스크린 리더가 읽는다.
  static const loading = '찜한 공연을 불러오는 중이에요.';

  static const showSearchHint = '찜한 공연을 검색해 보세요';
  static const artistSearchHint = '찜한 아티스트를 검색해 보세요';
  static const clearSearch = '검색어 지우기';

  /// 판매 상태 필터 칩. 순서가 시안 순서다.
  static const filterAll = '전체';
  static const filterOnSale = '판매 중';
  static const filterClosed = '판매 종료';

  /// 판매가 끝난 공연 카드에 붙는 뱃지. 필터 칩과 같은 말을 쓴다.
  static const closedBadge = '판매 종료';

  /// 공연 시작일이 정해지지 않은 공연의 일시 문구.
  static const dateUndecided = '일정 미정';

  static String showCount(int count) => '총 $count개';
  static String artistCount(int count) => '총 $count명';

  /// 정렬 메뉴. 공연과 아티스트가 두 번째 항목만 다르다.
  static const sortRecent = '최근 찜한 순';
  static const sortUpcoming = '공연 임박 순';
  static const sortName = '이름 순';
  static const sortMenu = '정렬';

  /// 하트 버튼. 찜리스트 안의 하트는 늘 찜한 상태라 '해제' 하나다.
  static const unfavorite = '찜 해제';

  /// 하트를 눌러 뺐을 때의 안내와 되돌리기.
  static const removed = '찜리스트에서 뺐어요';
  static const undo = '되돌리기';

  /// 로그아웃 상태에서 하트를 눌렀을 때. 아티스트 찜은 기기에 남지만 찜리스트는
  /// 로그인해야 보이므로, 공연과 아티스트 모두 이 안내를 띄운다.
  static const loginRequired = '로그인하고 찜해 보세요';
  static const login = '로그인';

  /// 찜리스트를 로그아웃 상태로 열었을 때. 아티스트 찜은 기기에만 있어
  /// 기기를 바꾸면 사라진다 — 공연과 안내 문구가 다른 이유다.
  static const guestShows = '로그인하면 찜한 공연이 보여요';
  static const guestShowsHint = '찜한 공연은 계정에 저장돼 기기를 바꿔도 남아요';
  static const guestArtists = '로그인하면 찜한 아티스트가 보여요';
  static const guestArtistsHint = '찜한 아티스트는 이 기기에 저장돼요';

  /// 서버에 남기지 못했을 때. 서버가 준 문구가 있으면 그쪽을 먼저 쓰고,
  /// 없을 때(예상 못 한 예외) 이 문구로 대신한다.
  static const toggleFailed = '찜을 저장하지 못했어요. 잠시 후 다시 시도해주세요.';

  /// 찜 목록 응답이 우리가 아는 모양이 아닐 때(프록시가 HTML 을 준 경우 등).
  static const unreadableResponse = '찜 목록을 읽지 못했어요.';

  /// 아티스트 줄의 초록 보조 문구. 누르면 그 이름으로 공연을 검색한다.
  static const artistSearchAction = '공연 검색하기';

  /// 아티스트 줄을 눌렀을 때 스크린 리더가 읽을 말. (예: `아이유 공연 검색`)
  static String searchShowsOf(String name) => '$name 공연 검색';

  /// 목록 맨 아래 안내.
  static const showFooter = '찜한 공연을 한곳에서 확인하세요';
  static const artistFooter = '좋아하는 아티스트의 공연을 모아보세요';

  // 빈 화면
  static const noShows = '아직 찜한 공연이 없어요';
  static const noShowsHint = '공연 카드의 하트를 누르면 여기에 모여요';
  static const noArtists = '아직 찜한 아티스트가 없어요';
  static const noArtistsHint = '검색 결과의 아티스트 하트를 누르면 여기에 모여요';
  static const browseShows = '공연 둘러보기';

  /// 검색어나 필터에 맞는 것이 없을 때. 검색어를 되비춰 준다.
  static String noShowsFor(String keyword) => "'$keyword' 에 맞는 공연이 없어요";
  static String noArtistsFor(String keyword) => "'$keyword' 에 맞는 아티스트가 없어요";

  /// 필터만 걸었는데 남은 게 없을 때.
  static const noShowsInFilter = '이 조건에 맞는 공연이 없어요';
}
