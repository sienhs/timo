import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/mock_home_data.dart';
import '../models/refresh_hint.dart';
import '../widgets/artist_section.dart';
import '../widgets/home_banner_carousel.dart';
import '../widgets/home_refresh_hint.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/show_card_badges.dart';
import '../widgets/show_card_row.dart';

/// 홈. `MainShellScreen` 의 첫 번째 탭 본문이다.
///
/// Scaffold 를 두지 않는다 — 셸이 이미 Scaffold 와 하단 바를 들고 있고,
/// 여기서 하나 더 만들면 하단 바 위에 또 다른 화면이 얹힌 모양이 된다.
///
/// 이 화면은 섹션을 순서대로 세우고 탭을 어디로 보낼지만 정한다. 섹션의
/// 내부 배치는 각 위젯이 안다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
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

  Future<void> _refresh() async {
    _collapseTimer?.cancel();
    setState(() => _isRefreshing = true);
    await Future<void>.delayed(MockHomeData.refreshDelay);
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
        HomeBannerCarousel(
          banners: MockHomeData.banners,
          onBannerPressed: (_) => _startBooking(context),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        const HomeSectionHeader(title: HomeStrings.artistSection),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        ArtistSection(
          artists: MockHomeData.artists,
          onArtistPressed: (artist) =>
              _notify(context, HomeStrings.artistNotReady(artist.name)),
          onMorePressed: () =>
              _notifyMoreNotReady(context, HomeStrings.artistSection),
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        HomeSectionHeader(
          title: HomeStrings.ticketOpenSection,
          moreLabel: HomeStrings.ticketOpenMore,
          onMorePressed: () =>
              _notifyMoreNotReady(context, HomeStrings.ticketOpenSection),
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        ShowCardRow(
          shows: MockHomeData.ticketOpenSoon,
          onShowPressed: (_) => _startBooking(context),
          badgeBuilder: (show, _) {
            final openAt = show.ticketOpenAt;
            return openAt == null ? null : TicketOpenBadge(openAt: openAt);
          },
        ),
        const SizedBox(height: HomeMetrics.sectionGap),
        HomeSectionHeader(
          title: HomeStrings.popularSection,
          moreLabel: HomeStrings.popularMore,
          onMorePressed: () =>
              _notifyMoreNotReady(context, HomeStrings.popularSection),
        ),
        const SizedBox(height: HomeMetrics.sectionTitleGap),
        ShowCardRow(
          shows: MockHomeData.popular,
          onShowPressed: (_) => _startBooking(context),
          // 목록 순서가 순위다. 1위부터 세므로 인덱스에 1을 더한다.
          badgeBuilder: (_, index) => RankBadge(rank: index + 1),
        ),
      ],
    );
  }

  /// 검색 화면은 아직 범위 밖이다. 검색 바는 시안대로 두고 안내만 띄운다.
  void _openSearch(BuildContext context) {
    _notify(context, HomeStrings.searchNotReady);
  }

  /// 공연 상세 화면이 아직 없어 예매 흐름의 첫 화면으로 바로 보낸다.
  ///
  /// 그래서 어떤 카드를 눌러도 목업 공연(2026 아이유 콘서트)의 좌석이 나온다.
  /// 상세가 생기면 여기서 공연 id 를 넘겨 상세로 보내고, 예매 진입은 상세가
  /// 맡는다. 지금 이 연결을 빼면 앱에서 예매 흐름에 들어갈 길이 없다.
  void _startBooking(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.zoneSelection);
  }

  void _notifyMoreNotReady(BuildContext context, String sectionTitle) {
    _notify(context, HomeStrings.moreNotReady(sectionTitle));
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
