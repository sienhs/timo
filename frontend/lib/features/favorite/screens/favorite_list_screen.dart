import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/underline_tab_bar.dart';
import '../../../routes/app_routes.dart';
import '../../shell/constants.dart';
import '../../shell/quick_menu_launcher.dart';
import '../../shell/widgets/app_bottom_nav_bar.dart';
import '../../shell/widgets/quick_menu_button.dart';
import '../constants.dart';
import '../models/favorite_artist.dart';
import '../models/favorite_filters.dart';
import '../models/favorite_show.dart';
import '../state/favorite_scope.dart';
import '../widgets/favorite_artist_tile.dart';
import '../widgets/favorite_empty_view.dart';
import '../widgets/favorite_filter_chips.dart';
import '../widgets/favorite_search_field.dart';
import '../widgets/favorite_show_card.dart';
import '../widgets/favorite_summary_row.dart';

/// 찜리스트. 빠른 메뉴의 '찜' 에서 들어온다.
///
/// 공연 탭과 아티스트 탭 둘이다. 목록은 [FavoriteScope] 에서 읽는다 — 서버가
/// 아니라 기기에 있는 것이라 기다리는 상태가 없고, 다른 화면에서 하트를
/// 누르면 스코프가 알려 이 화면도 따라 바뀐다.
///
/// 검색 칸·필터 칩·정렬은 모두 **기기에 있는 목록을 좁혀 보는 것**이다. 서버에
/// 묻지 않으므로 글자를 칠 때마다 바로 거른다.
class FavoriteListScreen extends StatefulWidget {
  const FavoriteListScreen({super.key});

  @override
  State<FavoriteListScreen> createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  static const _showTab = 0;

  int _tab = _showTab;
  final _search = TextEditingController();

  FavoriteShowFilter _filter = FavoriteShowFilter.all;
  FavoriteShowSort _showSort = FavoriteShowSort.recent;
  FavoriteArtistSort _artistSort = FavoriteArtistSort.recent;

  @override
  void initState() {
    super.initState();
    // 글자를 칠 때마다 목록을 다시 거른다. 기기에 있는 목록이라 비용이 없다.
    _search.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  /// 탭을 바꾸면 검색어는 비운다. 두 탭의 검색 대상(공연 제목 · 아티스트 이름)이
  /// 달라 한쪽에서 친 말이 다른 쪽에 남아 있으면 왜 목록이 비었는지 알기 어렵다.
  void _selectTab(int index) {
    if (index == _tab) return;
    _search.clear();
    setState(() => _tab = index);
  }

  void _openShowDetail(FavoriteShow show) {
    Navigator.pushNamed(context, AppRoutes.showDetail, arguments: show.id);
  }

  /// 아티스트 상세가 아직 없어 그 이름으로 공연을 검색한다.
  void _searchArtist(FavoriteArtist artist) {
    Navigator.pushNamed(context, AppRoutes.showSearch, arguments: artist.name);
  }

  void _browseShows() {
    Navigator.pushNamed(context, AppRoutes.showSearch);
  }

  /// 목록에서 뺀다. 잘못 눌렀을 때를 위해 되돌리기를 같이 띄운다 — 목록에서
  /// 사라지는 것이 곧 결과라 확인 다이얼로그까지 세우면 매번 두 번 누르게 된다.
  void _removeShow(FavoriteShow show) {
    final store = FavoriteScope.read(context);
    store.removeShow(show.id);
    _showUndo(() => store.toggleShow(show));
  }

  void _removeArtist(FavoriteArtist artist) {
    final store = FavoriteScope.read(context);
    store.removeArtist(artist.name);
    _showUndo(() => store.toggleArtist(artist));
  }

  /// 하단 바와 원형 버튼에 가리지 않게 그 위로 띄운다. 이전 안내가 남아 있으면
  /// 걷어낸다 — 연달아 뺐을 때 안내가 줄지어 기다릴 이유가 없다.
  void _showUndo(VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(FavoriteStrings.removed),
        action: SnackBarAction(
          label: FavoriteStrings.undo,
          textColor: AppColors.onPrimary,
          onPressed: onUndo,
        ),
        margin: const EdgeInsets.fromLTRB(
          FavoriteMetrics.horizontalPadding,
          0,
          FavoriteMetrics.horizontalPadding,
          ShellMetrics.fabProtrusion + FavoriteMetrics.snackBarGap,
        ),
      ),
    );
  }

  /// 하단 바의 홈·마이페이지로 간다. 검색 화면과 같은 방식 — 셸에 어느 탭을
  /// 열지 알리며 그 위에 쌓인 것을 걷어낸다.
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
    final favorites = FavoriteScope.of(context).favorites;
    final isShowTab = _tab == _showTab;

    return Scaffold(
      appBar: AppBar(
        title: const Text(FavoriteStrings.appBarTitle),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          tooltip: FavoriteStrings.back,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          UnderlineTabBar(
            labels: const [FavoriteStrings.showTab, FavoriteStrings.artistTab],
            counts: [favorites.shows.length, favorites.artists.length],
            selectedIndex: _tab,
            onSelected: _selectTab,
          ),
          const SizedBox(height: FavoriteMetrics.searchFieldTopGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FavoriteMetrics.horizontalPadding,
            ),
            child: FavoriteSearchField(
              controller: _search,
              hintText: isShowTab
                  ? FavoriteStrings.showSearchHint
                  : FavoriteStrings.artistSearchHint,
            ),
          ),
          const SizedBox(height: FavoriteMetrics.searchFieldBottomGap),
          Expanded(
            child: isShowTab
                ? _ShowTab(
                    shows: favorites.shows,
                    keyword: _search.text,
                    filter: _filter,
                    sort: _showSort,
                    onFilterSelected: (filter) =>
                        setState(() => _filter = filter),
                    onSortSelected: (sort) => setState(() => _showSort = sort),
                    onShowPressed: _openShowDetail,
                    onUnfavoritePressed: _removeShow,
                    onBrowsePressed: _browseShows,
                  )
                : _ArtistTab(
                    artists: favorites.artists,
                    keyword: _search.text,
                    sort: _artistSort,
                    onSortSelected: (sort) =>
                        setState(() => _artistSort = sort),
                    onArtistPressed: _searchArtist,
                    onUnfavoritePressed: _removeArtist,
                    onBrowsePressed: _browseShows,
                  ),
          ),
        ],
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
}

/// 공연 탭. 필터 칩 → `총 N개`·정렬 → 카드 목록 → 안내 한 줄.
///
/// 찜한 공연이 하나도 없으면 칩·정렬 없이 빈 화면만 그린다. 거를 것이 없는데
/// 조작부가 있으면 눌러도 아무 일이 없다.
class _ShowTab extends StatelessWidget {
  const _ShowTab({
    required this.shows,
    required this.keyword,
    required this.filter,
    required this.sort,
    required this.onFilterSelected,
    required this.onSortSelected,
    required this.onShowPressed,
    required this.onUnfavoritePressed,
    required this.onBrowsePressed,
  });

  final List<FavoriteShow> shows;
  final String keyword;
  final FavoriteShowFilter filter;
  final FavoriteShowSort sort;
  final ValueChanged<FavoriteShowFilter> onFilterSelected;
  final ValueChanged<FavoriteShowSort> onSortSelected;
  final ValueChanged<FavoriteShow> onShowPressed;
  final ValueChanged<FavoriteShow> onUnfavoritePressed;
  final VoidCallback onBrowsePressed;

  @override
  Widget build(BuildContext context) {
    if (shows.isEmpty) {
      return FavoriteEmptyView(
        title: FavoriteStrings.noShows,
        hint: FavoriteStrings.noShowsHint,
        onBrowsePressed: onBrowsePressed,
      );
    }

    final visible = sort.apply([
      for (final show in shows)
        if (filter.accepts(show) && matchesKeyword(show.title, keyword)) show,
    ]);

    return ListView(
      padding: const EdgeInsets.only(bottom: FavoriteMetrics.bottomGap),
      children: [
        FavoriteFilterChips(
          counts: {
            for (final f in FavoriteShowFilter.values)
              f: shows.where(f.accepts).length,
          },
          selected: filter,
          onSelected: onFilterSelected,
        ),
        const SizedBox(height: FavoriteMetrics.filterRowBottomGap),
        FavoriteSummaryRow(
          countLabel: FavoriteStrings.showCount(visible.length),
          sortLabels: [for (final s in FavoriteShowSort.values) s.label],
          selectedSort: sort.index,
          onSortSelected: (index) =>
              onSortSelected(FavoriteShowSort.values[index]),
        ),
        const SizedBox(height: FavoriteMetrics.summaryRowBottomGap),
        if (visible.isEmpty)
          _Message(
            keyword.trim().isEmpty
                ? FavoriteStrings.noShowsInFilter
                : FavoriteStrings.noShowsFor(keyword.trim()),
          )
        else ...[
          for (final show in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FavoriteMetrics.horizontalPadding,
                0,
                FavoriteMetrics.horizontalPadding,
                FavoriteMetrics.showCardGap,
              ),
              child: FavoriteShowCard(
                show: show,
                onPressed: () => onShowPressed(show),
                onUnfavoritePressed: () => onUnfavoritePressed(show),
              ),
            ),
          const _Footer(FavoriteStrings.showFooter),
        ],
      ],
    );
  }
}

/// 아티스트 탭. `총 N명`·정렬 → 줄 목록 → 안내 한 줄. 판매 상태가 없어 칩 줄은 없다.
class _ArtistTab extends StatelessWidget {
  const _ArtistTab({
    required this.artists,
    required this.keyword,
    required this.sort,
    required this.onSortSelected,
    required this.onArtistPressed,
    required this.onUnfavoritePressed,
    required this.onBrowsePressed,
  });

  final List<FavoriteArtist> artists;
  final String keyword;
  final FavoriteArtistSort sort;
  final ValueChanged<FavoriteArtistSort> onSortSelected;
  final ValueChanged<FavoriteArtist> onArtistPressed;
  final ValueChanged<FavoriteArtist> onUnfavoritePressed;
  final VoidCallback onBrowsePressed;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return FavoriteEmptyView(
        title: FavoriteStrings.noArtists,
        hint: FavoriteStrings.noArtistsHint,
        onBrowsePressed: onBrowsePressed,
      );
    }

    final visible = sort.apply([
      for (final artist in artists)
        if (matchesKeyword(artist.name, keyword)) artist,
    ]);

    return ListView(
      padding: const EdgeInsets.only(bottom: FavoriteMetrics.bottomGap),
      children: [
        FavoriteSummaryRow(
          countLabel: FavoriteStrings.artistCount(visible.length),
          sortLabels: [for (final s in FavoriteArtistSort.values) s.label],
          selectedSort: sort.index,
          onSortSelected: (index) =>
              onSortSelected(FavoriteArtistSort.values[index]),
        ),
        const SizedBox(height: FavoriteMetrics.summaryRowBottomGap),
        if (visible.isEmpty)
          _Message(FavoriteStrings.noArtistsFor(keyword.trim()))
        else ...[
          for (final artist in visible)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FavoriteMetrics.horizontalPadding,
                0,
                FavoriteMetrics.horizontalPadding,
                FavoriteMetrics.artistTileGap,
              ),
              child: FavoriteArtistTile(
                artist: artist,
                onPressed: () => onArtistPressed(artist),
                onUnfavoritePressed: () => onUnfavoritePressed(artist),
              ),
            ),
          const _Footer(FavoriteStrings.artistFooter),
        ],
      ],
    );
  }
}

/// 검색어·필터에 걸려 남은 것이 없을 때 목록 자리에 두는 한 줄.
class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FavoriteMetrics.horizontalPadding,
        vertical: FavoriteMetrics.emptyTopGap,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 목록 맨 아래의 연한 안내 한 줄.
class _Footer extends StatelessWidget {
  const _Footer(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FavoriteMetrics.horizontalPadding,
        vertical: FavoriteMetrics.footerGap,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
