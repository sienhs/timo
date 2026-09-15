import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../shell/constants.dart';
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
import '../widgets/home_section_header.dart';
import '../widgets/recent_search_chips.dart';
import '../widgets/recommended_artist_row.dart';
import '../widgets/related_artist_row.dart';
import '../widgets/search_field.dart';
import '../widgets/search_top_bar.dart';
import '../widgets/show_banner_card.dart';
import '../widgets/trending_keyword_list.dart';

/// 공연 검색. 홈 상단의 검색 바를 누르면 열린다.
///
/// 검색 전에는 최근 검색어 · 추천 검색어 · 실시간 인기 검색어를, 검색 뒤에는
/// 오픈 예정·예매중 공연 카드와 관련 아티스트를 보여 준다. 둘은 같은 화면의
/// 두 상태다 — [_shows] 가 null 이면 검색 전이다.
///
/// 검색어를 **제출했을 때만** 요청한다. 글자마다 보내면 요청이 글자 수만큼
/// 나가고, 늦게 온 앞 글자의 결과가 뒤 결과를 덮는다. 검색으로 이어지는 길은
/// 넷(키보드 · 최근 검색어 · 추천 검색어 · 인기 검색어)이지만 전부 [_search]
/// 하나를 거친다. 필터·정렬은 없다 — 요구사항의 검색·필터(#36)는 Could 라
/// 이번엔 키워드만 붙인다.
class ShowSearchScreen extends StatefulWidget {
  const ShowSearchScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    final api = HomeApiScope.of(context);
    _recommended = api.fetchRecommendedArtists();
    _trending = api.fetchTrendingKeywords();
    _loadRecent();
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
    setState(() => _recent = RecentSearches(saved));
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
      _artists = api.searchArtists(keyword);
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
      _artists = HomeApiScope.of(context).searchArtists(_keyword);
    });
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
    Navigator.pushNamed(
      context,
      AppRoutes.showDetail,
      arguments: show.id.toString(),
    );
  }

  /// 안내 스낵바. 하단 바와 원형 버튼에 가리지 않게 그 위로 띄운다.
  void _notifyFavoriteNotReady() {
    showInfoSnackBar(
      context,
      HomeStrings.favoriteNotReady,
      bottomMargin:
          ShellMetrics.barHeight + ShellMetrics.fabProtrusion + _snackBarGap,
    );
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
      // 키보드가 올라와도 본문을 줄이지 않는다. 줄이면 하단 바 위의 원형 버튼이
      // 키보드 위로 따라 올라와 검색 필드 옆에 떠 있게 된다. 대신 목록의 아래
      // 여백에 키보드 높이를 더해 마지막 항목까지 스크롤로 닿게 한다([_listPadding]).
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
              child: SearchField(
                controller: _controller,
                autofocus: true,
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
      // 시안에 하단 바가 그려져 있다. 이 화면은 셸 위에 얹힌 것이라 셸의 바가
      // 가려지므로 여기서 한 벌 더 단다. 어느 탭도 고르지 않은 상태(-1)다.
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
          builder: (context, artists) => RecommendedArtistRow(
            artists: artists,
            onArtistPressed: (artist) => _search(artist.name),
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        AsyncBoundary<TrendingKeywords>(
          future: _trending,
          onRetry: _reloadTrending,
          builder: (context, trending) => TrendingKeywordList(
            trending: trending,
            onKeywordPressed: _search,
          ),
        ),
      ],
    );
  }

  /// 검색 뒤. 공연 카드 → 관련 아티스트. 둘은 따로 기다리고 따로 실패한다.
  Widget _resultBody(
    Future<List<ShowSummary>> shows,
    Future<List<ArtistSummary>> artists,
  ) {
    return ListView(
      padding: _listPadding,
      children: [
        AsyncBoundary<List<ShowSummary>>(
          future: shows,
          onRetry: _retryShows,
          builder: (context, shows) => _ResultSection(
            shows: shows,
            keyword: _keyword,
            showAll: _showAll,
            onMorePressed: () => setState(() => _showAll = true),
            onShowPressed: _openShowDetail,
            onFavoritePressed: (_) => _notifyFavoriteNotReady(),
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        AsyncBoundary<List<ArtistSummary>>(
          future: artists,
          onRetry: _retryArtists,
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
                      onArtistPressed: (artist) => _search(artist.name),
                      onFavoritePressed: (_) => _notifyFavoriteNotReady(),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 안내 스낵바와 하단 바(원형 버튼 포함) 사이 틈.
const _snackBarGap = 12.0;

/// "오픈 예정 / 예매중" 섹션. 받은 공연 중 예매를 앞두거나 진행 중인 것만
/// 큰 카드로 세운다.
///
/// 처음엔 [HomeMetrics.searchPreviewCount] 건만 보이고, 넘치면 헤더의 더보기가
/// 나머지를 그 자리에서 펼친다. 걸러서 남은 게 없으면 검색어를 되비춘 빈 결과
/// 문구다.
class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.shows,
    required this.keyword,
    required this.showAll,
    required this.onMorePressed,
    required this.onShowPressed,
    required this.onFavoritePressed,
  });

  final List<ShowSummary> shows;
  final String keyword;
  final bool showAll;
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
                  onPressed: () => onShowPressed(show),
                  onFavoritePressed: () => onFavoritePressed(show),
                ),
              ),
            ),
      ],
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
