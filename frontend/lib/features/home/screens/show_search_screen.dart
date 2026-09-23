import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../favorite/constants.dart';
import '../../favorite/state/favorite_scope.dart';
import '../../favorite/utils/toggle_favorite_show.dart';
import '../../shell/quick_menu_launcher.dart';
import '../../shell/widgets/app_bottom_nav_bar.dart';
import '../../shell/widgets/quick_menu_button.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import '../models/recent_searches.dart';
import '../models/show_summary.dart';
import '../models/trending_keyword.dart';
import '../state/home_api_scope.dart';
import '../state/recent_search_scope.dart';
import '../utils/favorite_targets.dart';
import '../widgets/artist_section_skeleton.dart';
import '../widgets/home_section_header.dart';
import '../widgets/recent_search_chips.dart';
import '../widgets/recommended_artist_row.dart';
import '../widgets/related_artist_row.dart';
import '../widgets/search_top_bar.dart';
import '../widgets/show_banner_card.dart';
import '../widgets/show_card_badges.dart';
import '../widgets/show_card_list_skeleton.dart';
import '../widgets/trending_keyword_list.dart';
import '../widgets/trending_keyword_skeleton.dart';

/// 공연 검색. 홈 상단의 검색 바를 누르면 열린다. 검색 전에는 최근·추천·인기
/// 검색어를, 검색 뒤에는 공연 카드와 관련 아티스트를 보여 준다([_shows] 가 null
/// 이면 검색 전). 검색어를 제출했을 때만 요청하고 모든 진입 경로가 [_search] 를 거친다.
class ShowSearchScreen extends StatefulWidget {
  const ShowSearchScreen({super.key, this.initialKeyword});

  /// 열자마자 검색할 말. 찜리스트의 아티스트처럼 "이 이름으로 검색" 이 정해진
  /// 채로 들어올 때 준다. 없으면 검색 전 화면(최근·추천·인기 검색어)이다.
  final String? initialKeyword;

  @override
  State<ShowSearchScreen> createState() => _ShowSearchScreenState();
}

class _ShowSearchScreenState extends State<ShowSearchScreen> {
  final _controller = TextEditingController();

  /// 마지막으로 제출한 검색어. 빈 결과 문구에 되비춰 주고 다시 시도에 쓴다.
  String _keyword = '';

  /// 검색을 아직 안 했으면 null. 검색 전 화면과 결과 화면을 이걸로 가른다.
  /// 공연과 관련 아티스트는 따로 들고 있어 하나가 실패해도 다른 쪽은 보인다.
  Future<List<ShowSummary>>? _shows;
  Future<List<ArtistSummary>>? _artists;

  /// 검색 전 화면의 두 섹션. 화면을 열 때 한 번 받는다.
  late Future<List<ArtistSummary>> _recommended;
  late Future<TrendingKeywords> _trending;

  /// 기기에 저장된 최근 검색어. 아직 읽는 중이면 null 이고 그동안 섹션을
  /// 숨긴다 — 기기 저장소라 수 ms 면 온다.
  RecentSearches? _recent;

  /// 더보기를 눌러 결과 카드를 전부 펼쳤는지. 새로 검색하면 다시 접힌다.
  bool _showAll = false;

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void initState() {
    super.initState();
    final api = HomeApiScope.of(context);
    _recommended = api.fetchRecommendedArtists();
    _trending = api.fetchTrendingKeywords();
    _loadRecent();

    // 정해진 검색어가 있으면 바로 결과 화면으로 시작한다. initState 라 setState
    // 없이 필드에 직접 넣고, 최근 검색어에는 [_loadRecent] 가 저장소를 읽은 뒤 넣는다.
    final initial = widget.initialKeyword?.trim();
    if (initial != null && initial.isNotEmpty) {
      _keyword = initial;
      _controller.text = initial;
      _shows = api.search(initial);
      _artists = _searchArtistsAndSyncFavorites(initial);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 저장소를 못 읽어도(기기 설정 저장소 오류) 검색은 돼야 한다. 그때는 빈
  /// 목록으로 시작한다.
  Future<void> _loadRecent() async {
    final store = RecentSearchScope.of(context);
    List<String> saved;
    try {
      saved = await store.load();
    } catch (_) {
      saved = const [];
    }
    if (!mounted) return;
    var recent = RecentSearches(saved);
    // 검색어를 정해 두고 열렸으면 그 말도 최근 검색어에 남긴다.
    if (_keyword.isNotEmpty) {
      recent = recent.add(_keyword);
      RecentSearchScope.of(
        context,
      ).save(recent.items).catchError((Object _) {});
    }
    setState(() => _recent = recent);
  }

  void _search(String raw) {
    final keyword = raw.trim();
    if (keyword.isEmpty) return;
    final api = HomeApiScope.of(context);
    // 칩·인기 검색어로 검색했을 때도 필드에 그 말이 보여야 무엇을 찾았는지 안다.
    _controller.value = TextEditingValue(
      text: keyword,
      selection: TextSelection.collapsed(offset: keyword.length),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _keyword = keyword;
      _showAll = false;
      _shows = api.search(keyword);
      _artists = _searchArtistsAndSyncFavorites(keyword);
    });
    _remember(keyword);
  }

  /// 최근 검색어에 넣는다. 저장소를 아직 못 읽었으면(막 열자마자 검색) 건너뛴다
  /// — 빈 목록 위에 얹어 저장하면 원래 있던 검색어를 덮어 지운다.
  void _remember(String keyword) {
    final recent = _recent;
    if (recent == null) return;
    _saveRecent(recent.add(keyword));
  }

  void _removeRecent(String keyword) {
    final recent = _recent;
    if (recent == null) return;
    _saveRecent(recent.remove(keyword));
  }

  void _clearRecent() {
    final recent = _recent;
    if (recent == null) return;
    _saveRecent(recent.clear());
  }

  /// 화면을 먼저 바꾸고 저장은 뒤따른다. 저장이 실패해도 화면은 이미 맞고,
  /// 다음 검색 때 다시 저장되므로 실패를 알리지 않는다.
  void _saveRecent(RecentSearches next) {
    setState(() => _recent = next);
    RecentSearchScope.of(context).save(next.items).catchError((Object _) {});
  }

  // setState 의 콜백이 Future 를 돌려주면 안 된다(화살표 함수로 대입하면 대입식의
  // 값인 Future 가 반환된다). 그래서 블록으로 쓴다.
  void _retryShows() {
    setState(() {
      _shows = HomeApiScope.of(context).search(_keyword);
    });
  }

  void _retryArtists() {
    setState(() {
      _artists = _searchArtistsAndSyncFavorites(_keyword);
    });
  }

  /// 아티스트를 검색하고, 결과 중 이미 찜한 아티스트의 스냅샷을 서버가 준 최신
  /// 모습으로 맞춘다. 찜리스트는 찜한 순간의 모습을 기기에 남기기 때문이다.
  /// 검색 실패는 [AsyncBoundary] 가 알리므로 동기화 쪽에서는 넘긴다.
  Future<List<ArtistSummary>> _searchArtistsAndSyncFavorites(String keyword) {
    final store = FavoriteScope.read(context);
    final result = HomeApiScope.of(context).searchArtists(keyword);
    result
        .then(
          (artists) => store.refreshArtists([
            for (final artist in artists) artist.toFavorite(),
          ]),
        )
        .ignore();
    return result;
  }

  void _reloadRecommended() {
    setState(() {
      _recommended = HomeApiScope.of(context).fetchRecommendedArtists();
    });
  }

  void _reloadTrending() {
    setState(() {
      _trending = HomeApiScope.of(context).fetchTrendingKeywords();
    });
  }

  /// 검색 전 상태로. 지우기 X 를 눌렀을 때다.
  void _reset() {
    setState(() {
      _keyword = '';
      _shows = null;
      _artists = null;
      _showAll = false;
    });
  }

  void _openShowDetail(ShowSummary show) {
    Navigator.pushNamed(context, AppRoutes.showDetail, arguments: show.id);
  }

  /// 공연 찜은 서버에 남는다. 로그인 안내와 실패 알림은 공통 동작이 맡는다.
  Future<void> _toggleFavoriteShow(ShowSummary show) =>
      toggleFavoriteShow(context, show.toFavorite());

  /// 아티스트 찜은 기기에만 남지만 찜리스트는 로그인해야 보인다. 그래서 공연
  /// 하트와 같이 로그아웃 상태면 찜하지 않고 안내한다 — 눌린 하트가 어디에도
  /// 나타나지 않는 편이 더 헷갈린다.
  void _toggleFavoriteArtist(ArtistSummary artist) {
    if (!_isLoggedIn) {
      showInfoSnackBar(context, FavoriteStrings.loginRequired);
      return;
    }
    FavoriteScope.read(context).toggleArtist(artist.toFavorite());
  }

  /// 하단 바의 홈·마이페이지로 간다. 내 티켓 화면과 같은 방식 — 셸에 어느
  /// 탭을 열지 알리며 그 위에 쌓인 것을 걷어낸다.
  void _goToShellTab(int index) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shows = _shows;
    final artists = _artists;
    return Scaffold(
      // 키보드가 올라와도 본문을 줄이지 않는다. 줄이면 원형 버튼이 키보드 위로
      // 따라 올라온다. 대신 목록 아래 여백에 키보드 높이를 더한다([_listPadding]).
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SearchTopBar(onBackPressed: () => Navigator.maybePop(context)),
            const SizedBox(height: HomeMetrics.searchFieldTopGap),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HomeMetrics.horizontalPadding,
              ),
              child: AppSearchField(
                controller: _controller,
                hintText: HomeStrings.searchHint,
                clearLabel: HomeStrings.clearSearch,
                // 검색어를 정해 두고 열렸으면 결과를 보러 온 것이라 키보드를
                // 올리지 않는다.
                autofocus: widget.initialKeyword == null,
                onSubmitted: _search,
                onCleared: _reset,
              ),
            ),
            const SizedBox(height: HomeMetrics.searchFieldBottomGap),
            Expanded(
              child: shows == null || artists == null
                  ? _idleBody()
                  : _resultBody(shows, artists),
            ),
          ],
        ),
      ),
      // 이 화면은 셸 위에 얹혀 셸의 하단 바가 가려지므로 여기서 한 벌 더 단다.
      // 어느 탭도 고르지 않은 상태(-1)다.
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: -1,
        onTabSelected: _goToShellTab,
        onQuickMenuPressed: () => openQuickMenu(context),
      ),
      floatingActionButton: QuickMenuButton(
        onPressed: () => openQuickMenu(context),
      ),
      floatingActionButtonLocation: quickMenuButtonLocation,
    );
  }

  /// 목록 아래 여백. 원형 버튼에 가리지 않을 만큼 띄우고, 키보드가 열려 있으면
  /// 그 높이만큼 더 띄운다 — Scaffold 가 본문을 줄여 주지 않기 때문이다.
  EdgeInsets get _listPadding => EdgeInsets.only(
    bottom: HomeMetrics.bottomGap + MediaQuery.viewInsetsOf(context).bottom,
  );

  /// 검색 전. 최근 검색어(있을 때만) → 추천 검색어 → 실시간 인기 검색어.
  Widget _idleBody() {
    final recent = _recent;
    return ListView(
      padding: _listPadding,
      children: [
        if (recent != null && !recent.isEmpty) ...[
          RecentSearchChips(
            keywords: recent.items,
            onKeywordPressed: _search,
            onRemovePressed: _removeRecent,
            onClearAllPressed: _clearRecent,
          ),
          const SizedBox(height: HomeMetrics.sectionGap),
        ],
        const HomeSectionHeader(title: HomeStrings.recommendedSection),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        AsyncBoundary<List<ArtistSummary>>(
          future: _recommended,
          onRetry: _reloadRecommended,
          loading: const ArtistSectionSkeleton(rows: 1),
          builder: (context, artists) => RecommendedArtistRow(
            artists: artists,
            onArtistPressed: (artist) => _search(artist.name),
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        AsyncBoundary<TrendingKeywords>(
          future: _trending,
          onRetry: _reloadTrending,
          loading: const TrendingKeywordSkeleton(),
          builder: (context, trending) => TrendingKeywordList(
            trending: trending,
            onKeywordPressed: _search,
          ),
        ),
      ],
    );
  }

  /// 검색 뒤. 공연 카드 → 관련 아티스트. 둘은 따로 기다리고 따로 실패한다.
  /// 찜 목록은 여기서 구독해, 하트를 누르면 이 화면이 다시 그려진다.
  Widget _resultBody(
    Future<List<ShowSummary>> shows,
    Future<List<ArtistSummary>> artists,
  ) {
    final favorites = FavoriteScope.of(context).favorites;
    return ListView(
      padding: _listPadding,
      children: [
        AsyncBoundary<List<ShowSummary>>(
          future: shows,
          onRetry: _retryShows,
          loading: const _ResultSkeleton(),
          builder: (context, shows) => _ResultSection(
            shows: shows,
            keyword: _keyword,
            showAll: _showAll,
            favoriteShowIds: {for (final show in favorites.shows) show.id},
            onMorePressed: () => setState(() => _showAll = true),
            onShowPressed: _openShowDetail,
            onFavoritePressed: _toggleFavoriteShow,
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        AsyncBoundary<List<ArtistSummary>>(
          future: artists,
          onRetry: _retryArtists,
          // 관련 아티스트는 없을 수도 있는 섹션이라 뼈대 없이 자리를 비워 둔다.
          // 뼈대를 세우면 아티스트가 없는 검색어에서 잠깐 떴다가 사라진다.
          loading: const SizedBox.shrink(),
          builder: (context, artists) => artists.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HomeSectionHeader(
                      title: HomeStrings.relatedArtistSection,
                    ),
                    const SizedBox(height: HomeMetrics.sectionTitleGap),
                    RelatedArtistRow(
                      artists: artists,
                      // 로그아웃이면 기기에 남은 찜이 있어도 빈 하트로 둔다.
                      // 찜리스트에서 보이지 않는 것이 채워져 보이면 안 된다.
                      favoriteNames: _isLoggedIn
                          ? {
                              for (final artist in favorites.artists)
                                artist.name,
                            }
                          : const {},
                      onArtistPressed: (artist) => _search(artist.name),
                      onFavoritePressed: _toggleFavoriteArtist,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// "오픈 예정 / 예매중" 섹션. 예매를 앞두거나 진행 중인 공연만 큰 카드로 세운다.
/// 처음엔 [HomeMetrics.searchPreviewCount] 건만 보이고 더보기가 나머지를 펼친다.
/// 걸러서 남은 게 없으면 검색어를 되비춘 빈 결과 문구다.
class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.shows,
    required this.keyword,
    required this.showAll,
    required this.favoriteShowIds,
    required this.onMorePressed,
    required this.onShowPressed,
    required this.onFavoritePressed,
  });

  final List<ShowSummary> shows;
  final String keyword;
  final bool showAll;

  /// 찜한 공연 번호. 카드의 하트를 채울지 가른다.
  final Set<int> favoriteShowIds;

  final VoidCallback onMorePressed;
  final ValueChanged<ShowSummary> onShowPressed;
  final ValueChanged<ShowSummary> onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final bookable = shows.where((show) => show.isOpenOrUpcoming).toList();
    final hasMore =
        !showAll && bookable.length > HomeMetrics.searchPreviewCount;
    final visible = showAll
        ? bookable
        : bookable.take(HomeMetrics.searchPreviewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: HomeStrings.resultSection,
          moreLabel: hasMore ? HomeStrings.resultMore : null,
          onMorePressed: hasMore ? onMorePressed : null,
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        if (bookable.isEmpty)
          _Message(HomeStrings.searchEmpty(keyword))
        else
          for (final show in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HomeMetrics.horizontalPadding,
                0,
                HomeMetrics.horizontalPadding,
                HomeMetrics.searchCardGap,
              ),
              child: SizedBox(
                height: HomeMetrics.searchCardHeight,
                child: ShowBannerCard(
                  show: show,
                  isFavorite: favoriteShowIds.contains(show.id),
                  // 섹션 제목이 "오픈 예정 / 예매중" 이라 둘이 한데 섞인다.
                  badge: BookingStatusBadge(show: show),
                  onPressed: () => onShowPressed(show),
                  onFavoritePressed: () => onFavoritePressed(show),
                ),
              ),
            ),
      ],
    );
  }
}

/// 검색 결과를 기다리는 동안의 자리. 제목은 뼈대로 두지 않고 그대로 적고,
/// 카드는 미리보기 개수([HomeMetrics.searchPreviewCount])만큼만 세운다.
class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: HomeStrings.loading,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeader(title: HomeStrings.resultSection),
          SizedBox(height: HomeMetrics.sectionTitleGap),
          ShowCardListSkeleton(count: HomeMetrics.searchPreviewCount),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
        vertical: HomeMetrics.sectionTitleGap,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
