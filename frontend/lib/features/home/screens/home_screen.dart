import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/artist_summary.dart';
import '../models/refresh_hint.dart';
import '../models/show_summary.dart';
import '../state/home_api_scope.dart';
import '../widgets/artist_section.dart';
import '../widgets/artist_section_skeleton.dart';
import '../widgets/home_banner_carousel.dart';
import '../widgets/home_banner_skeleton.dart';
import '../widgets/home_refresh_hint.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/show_card_badges.dart';
import '../widgets/show_card_row.dart';
import '../widgets/show_card_row_skeleton.dart';

/// 받아 온 공연 중 줄에 세울 것만 고른다. 줄마다 기준이 달라(오픈 예정은
/// 아직 안 열린 것, 인기는 예매로 이어지는 것) 섹션이 정해서 넘긴다.
typedef _ShowSelector = List<ShowSummary> Function(List<ShowSummary> shows);

/// 홈. `MainShellScreen` 의 첫 번째 탭 본문이다.
///
/// Scaffold 를 두지 않는다 — 셸이 이미 Scaffold 와 하단 바를 들고 있고,
/// 여기서 하나 더 만들면 하단 바 위에 또 다른 화면이 얹힌 모양이 된다.
///
/// 이 화면은 섹션을 순서대로 세우고 탭을 어디로 보낼지만 정한다. 섹션의
/// 내부 배치는 각 위젯이 안다. 공연 두 줄(오픈 예정 · 인기)은 서버에서
/// 받아 오고, 배너는 인기 공연의 앞 몇 건을 그대로 올린다. 아티스트도 같은
/// 길로 받아 오지만 서버 API 가 아직 없어 구현이 목업을 돌려준다 — 이 화면은
/// 그 사정을 모른다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 섹션별 요청. 따로 들고 있어 하나가 실패해도 다른 섹션은 그대로 보인다.
  /// 새로 고침·다시 시도는 이 값을 새 요청으로 바꾸는 일이다.
  late Future<List<ArtistSummary>> _artists;
  late Future<List<ShowSummary>> _ticketOpenSoon;
  late Future<List<ShowSummary>> _popular;

  /// 새로 고치는 중인지. 스피너는 [RefreshIndicator] 가 `onRefresh` 의
  /// Future 로 알아서 돌리고, 이 값은 안내 줄을 열어 두는 데만 쓴다.
  bool _isRefreshing = false;

  /// 위쪽에서 당기고 있는 중인지. 손을 떼기 전부터 안내를 보여 준다.
  bool _isPulling = false;

  /// 지금까지 안내를 보여 준 횟수. 문구를 순서대로 돌리는 데 쓴다.
  int _hintCount = 0;

  Timer? _collapseTimer;

  RefreshHint get _hint =>
      HomeStrings.refreshHints[_hintCount % HomeStrings.refreshHints.length];

  bool get _isHintVisible => _isPulling || _isRefreshing;

  @override
  void initState() {
    super.initState();
    final api = HomeApiScope.of(context);
    _artists = api.fetchPopularArtists();
    _ticketOpenSoon = api.fetchTicketOpenSoon();
    _popular = api.fetchPopular();
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _reloadArtists() {
    setState(() {
      _artists = HomeApiScope.of(context).fetchPopularArtists();
    });
  }

  void _reloadTicketOpenSoon() {
    setState(() {
      _ticketOpenSoon = HomeApiScope.of(context).fetchTicketOpenSoon();
    });
  }

  void _reloadPopular() {
    setState(() {
      _popular = HomeApiScope.of(context).fetchPopular();
    });
  }

  /// 스크롤 알림으로 '당기는 중'을 알아낸다.
  ///
  /// `metrics.pixels` 를 보지 않는다 — 안드로이드 기본 물리(Clamping)는
  /// 스크롤 위치를 0 아래로 내리지 않고, 넘친 양을 [OverscrollNotification]
  /// 으로만 알려 준다. `dragDetails` 가 있는 알림만 세는 것도 같은 이유다.
  /// 손가락이 끌 때만 안내를 띄우고, 관성으로 튀는 건 무시한다.
  bool _onScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification) {
      final isPullingDownAtTop =
          notification.dragDetails != null &&
          notification.overscroll < 0 &&
          notification.metrics.extentBefore == 0;
      if (isPullingDownAtTop && !_isPulling) {
        _collapseTimer?.cancel();
        setState(() => _isPulling = true);
      }
    } else if (notification is ScrollEndNotification) {
      _scheduleCollapse();
    }
    return false;
  }

  /// 손을 뗀 뒤 새로 고침이 시작되지 않으면 안내를 접는다.
  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(HomeMetrics.refreshHintCollapseGrace, () {
      if (!mounted || _isRefreshing) return;
      _closeHint();
    });
  }

  void _closeHint() {
    setState(() {
      _isPulling = false;
      // 다음 번엔 다음 문구가 나온다.
      _hintCount++;
    });
  }

  /// 섹션을 전부 다시 받아 온다. 실패는 각 줄의 [AsyncBoundary] 가 보여 주므로
  /// 여기서는 끝나기만 기다린다 — 여기서 던지면 스피너가 멈추지 않는다.
  Future<void> _refresh() async {
    _collapseTimer?.cancel();
    setState(() => _isRefreshing = true);
    _reloadArtists();
    _reloadTicketOpenSoon();
    _reloadPopular();
    await Future.wait<Object>([
      _artists,
      _ticketOpenSoon,
      _popular,
    ]).then<void>((_) {}, onError: (Object _) {});
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    _closeHint();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      // 상단 바는 스크롤 밖에 둔다. 하단 바처럼 늘 같은 자리에 있어야
      // 어느 위치에서든 바로 검색으로 들어갈 수 있다.
      child: Column(
        children: [
          HomeTopBar(onSearchPressed: () => _openSearch(context)),
          HomeRefreshHint(
            message: _hint,
            visible: _isHintVisible,
            refreshing: _isRefreshing,
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                displacement: HomeMetrics.refreshDisplacement,
                semanticsLabel: _hint.plainText,
                child: _sections(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sections(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: HomeMetrics.bottomGap),
      children: [
        // 배너 API 가 없어 인기 공연 응답을 같이 쓴다. 인기 줄과 같은 Future
        // 라 요청은 한 번만 나간다. 실패 문구는 인기 줄이 이미 보여 주므로
        // 여기서는 자리를 비운다 — 같은 문구가 위아래 두 번 뜨면 화면이 실패로
        // 도배된다.
        AsyncBoundary<List<ShowSummary>>(
          future: _popular,
          onRetry: _reloadPopular,
          loading: const HomeBannerSkeleton(),
          error: const SizedBox.shrink(),
          builder: (context, shows) => HomeBannerCarousel(
            banners: _bookable(shows).take(HomeMetrics.bannerCount).toList(),
            onBannerPressed: (show) => _openShowDetail(context, show.id),
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        const HomeSectionHeader(title: HomeStrings.artistSection),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        AsyncBoundary<List<ArtistSummary>>(
          future: _artists,
          onRetry: _reloadArtists,
          loading: const ArtistSectionSkeleton(),
          builder: (context, artists) => ArtistSection(
            artists: artists,
            onArtistPressed: (artist) => _openSearch(context, artist.name),
          ),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        HomeSectionHeader(
          title: HomeStrings.ticketOpenSection,
          moreLabel: HomeStrings.ticketOpenMore,
          onMorePressed: () =>
              Navigator.pushNamed(context, AppRoutes.openSoonShows),
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        _showRow(
          future: _ticketOpenSoon,
          onRetry: _reloadTicketOpenSoon,
          select: _unopened,
          badgeBuilder: (show, _) {
            final openAt = show.ticketOpenAt;
            return openAt == null ? null : TicketOpenBadge(openAt: openAt);
          },
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        HomeSectionHeader(
          title: HomeStrings.popularSection,
          moreLabel: HomeStrings.popularMore,
          onMorePressed: () => Navigator.pushNamed(context, AppRoutes.allShows),
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        _showRow(
          future: _popular,
          onRetry: _reloadPopular,
          select: _bookable,
          // 목록 순서가 순위다. 1위부터 세므로 인덱스에 1을 더한다. 거르고 난
          // 뒤의 자리로 센다 — 끝난 공연을 빼 놓고 2위부터 시작하면 1위가
          // 어디 갔는지 알 수 없다.
          badgeBuilder: (_, index) => RankBadge(rank: index + 1),
        ),
      ],
    );
  }

  /// 서버에서 받아 오는 카드 한 줄. 기다리는 동안은 빈 카드, 실패하면
  /// 문구와 다시 시도, 비어 있으면 안내 한 줄이다.
  Widget _showRow({
    required Future<List<ShowSummary>> future,
    required VoidCallback onRetry,
    required _ShowSelector select,
    required ShowBadgeBuilder badgeBuilder,
  }) {
    return AsyncBoundary<List<ShowSummary>>(
      future: future,
      onRetry: onRetry,
      loading: const ShowCardRowSkeleton(),
      builder: (context, shows) {
        final selected = select(shows);
        if (selected.isEmpty) return const _EmptyRow();
        return ShowCardRow(
          shows: selected,
          onShowPressed: (show) => _openShowDetail(context, show.id),
          badgeBuilder: badgeBuilder,
        );
      },
    );
  }

  /// 아직 오픈하지 않은 공연만. 서버가 `status` 로 한 번 걸러 주지만, 오픈
  /// 시각이 지나도 상태가 밀리지 않은 공연이 섞여 온다 —
  /// [ShowSummary.opensAfter] 주석에 사정을 적어 두었다.
  List<ShowSummary> _unopened(List<ShowSummary> shows) {
    final now = DateTime.now();
    return shows.where((show) => show.opensAfter(now)).toList();
  }

  /// 예매를 앞두었거나 진행 중인 공연만. 인기 줄과 배너가 함께 쓴다 —
  /// 끝나거나 취소된 공연이 "인기" 로 올라오면 눌러 봐야 예매를 못 한다.
  List<ShowSummary> _bookable(List<ShowSummary> shows) =>
      shows.where((show) => show.isOpenOrUpcoming).toList();

  /// 검색 화면으로 보낸다. [keyword] 를 주면 그 말로 검색된 결과에서 시작한다 —
  /// 아티스트 상세 화면은 따로 두지 않고 검색 결과가 그 자리를 맡는다.
  void _openSearch(BuildContext context, [String? keyword]) {
    Navigator.pushNamed(context, AppRoutes.showSearch, arguments: keyword);
  }

  /// 공연 상세로 보낸다. 예매 진입은 상세가 맡는다 — 홈에서 좌석 선택으로
  /// 바로 가면 무엇을 예매하는지 모른 채 좌석을 고르게 된다.
  void _openShowDetail(BuildContext context, int showId) {
    Navigator.pushNamed(context, AppRoutes.showDetail, arguments: showId);
  }

}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
        vertical: HomeMetrics.sectionTitleGap,
      ),
      child: Text(
        HomeStrings.noShows,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
