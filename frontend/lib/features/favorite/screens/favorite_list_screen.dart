import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../core/widgets/underline_tab_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../shell/constants.dart';
import '../../shell/quick_menu_launcher.dart';
import '../../shell/widgets/app_bottom_nav_bar.dart';
import '../../shell/widgets/quick_menu_button.dart';
import '../constants.dart';
import '../models/favorite_artist.dart';
import '../models/favorite_filters.dart';
import '../models/favorite_show.dart';
import '../state/favorite_scope.dart';
import '../utils/toggle_favorite_show.dart';
import '../widgets/favorite_artist_tile.dart';
import '../widgets/favorite_empty_view.dart';
import '../widgets/favorite_filter_chips.dart';
import '../widgets/favorite_search_field.dart';
import '../widgets/favorite_show_card.dart';
import '../widgets/favorite_summary_row.dart';

/// 찜리스트. 빠른 메뉴의 '찜' 에서 들어온다.
///
/// 공연 탭과 아티스트 탭 둘인데 목록이 사는 곳이 다르다. **공연은 서버**라
/// 화면에 들어올 때 받아 오고(기다림·실패는 [AsyncBoundary] 가 맡는다),
/// 로그아웃 상태면 받을 것이 없어 로그인 안내를 대신 그린다. **아티스트는
/// 기기**에 있어 기다리는 상태가 없다.
///
/// 받아 온 목록은 [FavoriteScope] 에서 읽는다. 다른 화면에서 하트를 누르면
/// 스코프가 알려 이 화면도 따라 바뀐다.
///
/// 검색 칸·필터 칩·정렬은 모두 **받아 둔 목록을 좁혀 보는 것**이다. 서버에
/// 다시 묻지 않으므로 글자를 칠 때마다 바로 거른다.
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

  /// 진행 중인 찜 공연 조회. 로그인 상태일 때만 있다.
  Future<List<FavoriteShow>>? _shows;

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void initState() {
    super.initState();
    // 글자를 칠 때마다 목록을 다시 거른다. 받아 둔 목록이라 비용이 없다.
    _search.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인한 채로 들어왔거나 이 화면에서 로그인하고 돌아왔을 때 받아 온다.
    // 로그아웃되면 들고 있던 것을 버린다 — 그러면 공연 탭이 로그인 안내로
    // 바뀐다(양도마켓·충전 화면과 같은 방식).
    if (_isLoggedIn) {
      _shows ??= FavoriteScope.read(context).loadShows();
    } else {
      _shows = null;
    }
  }

  /// 서버에 다시 묻는다. 실패 화면의 '다시 시도' 가 쓴다.
  void _reloadShows() {
    setState(() {
      _shows = FavoriteScope.read(context).loadShows();
    });
  }

  void _goToLogin() {
    Navigator.pushNamed(context, AppRoutes.login);
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
  ///
  /// 카드는 서버 응답을 기다리지 않고 바로 빠진다. 서버가 거절하면 저장소가
  /// 되돌려 카드가 다시 나타나므로, 되돌리기 안내 자리에 오류를 띄운다
  /// (오류 스낵바가 앞의 안내를 걷어낸다).
  Future<void> _removeShow(FavoriteShow show) async {
    final removal = FavoriteScope.read(context).removeShow(show.id);
    _showUndo(() => toggleFavoriteShow(context, show));
    try {
      await removal;
    } on ApiException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    } catch (_) {
      if (mounted) showErrorSnackBar(context, FavoriteStrings.toggleFailed);
    }
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

  /// 공연 탭. 로그아웃이면 로그인 안내, 로그인 상태면 서버에서 받아 온 목록이다.
  ///
  /// [AsyncBoundary] 가 주는 값 대신 저장소가 들고 있는 [shows] 를 그린다.
  /// 받아 온 뒤에도 하트를 누르면 목록이 바뀌는데, 그건 저장소가 알리는
  /// 것이라 Future 가 준 값은 이미 낡았다.
  Widget _showTabBody(List<FavoriteShow> shows) {
    final pending = _shows;
    if (pending == null) {
      return FavoriteEmptyView(
        title: FavoriteStrings.guestShows,
        hint: FavoriteStrings.guestShowsHint,
        actionLabel: FavoriteStrings.login,
        onActionPressed: _goToLogin,
      );
    }

    return AsyncBoundary<List<FavoriteShow>>(
      future: pending,
      onRetry: _reloadShows,
      builder: (context, _) => _ShowTab(
        shows: shows,
        keyword: _search.text,
        filter: _filter,
        sort: _showSort,
        onFilterSelected: (filter) => setState(() => _filter = filter),
        onSortSelected: (sort) => setState(() => _showSort = sort),
        onShowPressed: _openShowDetail,
        onUnfavoritePressed: _removeShow,
        onBrowsePressed: _browseShows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = FavoriteScope.of(context).favorites;
    final isShowTab = _tab == _showTab;

    return Scaffold(
      // 키보드가 올라와도 본문을 줄이지 않는다. 줄이면 하단 바 위의 원형 버튼이
      // 키보드 위로 따라 올라와 본문 한가운데에 떠 있게 된다(공연 검색 화면과
      // 같은 사정). 대신 목록 아래 여백에 키보드 높이를 더해 마지막 항목까지
      // 스크롤로 닿게 한다([_listBottomPadding]).
      resizeToAvoidBottomInset: false,
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
                ? _showTabBody(favorites.shows)
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
        onActionPressed: onBrowsePressed,
      );
    }

    final visible = sort.apply([
      for (final show in shows)
        if (filter.accepts(show) && matchesKeyword(show.title, keyword)) show,
    ]);

    return ListView(
      padding: _listBottomPadding(context),
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
        onActionPressed: onBrowsePressed,
      );
    }

    final visible = sort.apply([
      for (final artist in artists)
        if (matchesKeyword(artist.name, keyword)) artist,
    ]);

    return ListView(
      padding: _listBottomPadding(context),
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

/// 목록 아래 여백. 원형 버튼에 가리지 않을 만큼 띄우고, 키보드가 열려 있으면
/// 그 높이만큼 더 띄운다 — Scaffold 가 본문을 줄여 주지 않기 때문이다.
EdgeInsets _listBottomPadding(BuildContext context) => EdgeInsets.only(
  bottom: FavoriteMetrics.bottomGap + MediaQuery.viewInsetsOf(context).bottom,
);
