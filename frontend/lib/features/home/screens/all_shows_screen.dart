import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/underline_tab_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/show_filters.dart';
import '../models/show_summary.dart';
import '../state/home_api_scope.dart';
import '../widgets/show_card_badges.dart';
import '../widgets/show_date_range_sheet.dart';
import '../widgets/show_filter_bar.dart';
import '../widgets/show_list_app_bar.dart';
import '../widgets/show_list_skeleton.dart';
import '../widgets/show_list_view.dart';

/// 공연 전체 조회. 홈의 "인기 공연" 더보기로 들어온다. 서버에서 상태로 거르지
/// 않고 다 받아 탭으로 나눠 본다 — `예매 가능`(기본)은 예매 중·매진 공연만,
/// `예매 마감` 은 종료·취소 공연만, `모두 보기` 는 전부다. 서버의
/// `status` 는 값 하나만 받으므로 전체를 한 번 받은 뒤 화면에서 상태를 묶는다.
///
/// 탭 아래 필터 줄에서 날짜와 정렬을 고른다. 거르는 순서는 탭 → 날짜 → 정렬이라
/// "10월 안에서 인기순" 처럼 겹쳐 쓸 수 있다. 서버에는 다시 묻지 않는다 — 받아
/// 둔 목록(인기순 최대 100건)을 그 자리에서 거르고 세운다.
class AllShowsScreen extends StatefulWidget {
  const AllShowsScreen({super.key, this.clock = DateTime.now});

  /// 오늘을 정하는 시계. 달력이 이 날 앞을 잠그고 빠른 선택이 이 날을 기준으로
  /// 잡는다. 테스트가 고정한다.
  final DateTime Function() clock;

  @override
  State<AllShowsScreen> createState() => _AllShowsScreenState();
}

class _AllShowsScreenState extends State<AllShowsScreen> {
  /// 탭 순서. 화면이 이 순서로만 가르므로 상수로 둔다.
  static const _bookableTab = 0;
  static const _closedTab = 1;

  late Future<List<ShowSummary>> _shows;
  int _selectedTab = _bookableTab;
  ShowDateRange? _range;
  ShowSort _sort = ShowSort.popular;

  @override
  void initState() {
    super.initState();
    _shows = HomeApiScope.of(context).fetchAllShows();
  }

  void _reload() {
    setState(() {
      _shows = HomeApiScope.of(context).fetchAllShows();
    });
  }

  /// 지금 탭이 보여 주는 공연. 날짜로 거르기 전이다 — 시트의 점과 건수는 이
  /// 목록에서 센다.
  List<ShowSummary> _inTab(List<ShowSummary> shows) => switch (_selectedTab) {
    _bookableTab => shows.where((show) => show.isOnSaleGroup).toList(),
    _closedTab => shows.where((show) => show.isBookingClosed).toList(),
    _ => shows,
  };

  List<ShowSummary> _inRange(List<ShowSummary> shows) {
    final range = _range;
    return range == null ? shows : shows.where(range.accepts).toList();
  }

  void _openDateSheet(List<ShowSummary> shows) {
    showShowDateRangeSheet(
      context,
      shows: _inTab(shows),
      initial: _range,
      today: widget.clock(),
      onApplied: (range) => setState(() => _range = range),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const ShowListAppBar(title: HomeStrings.allShowsListTitle),
      body: SafeArea(
        bottom: false,
        child: AsyncBoundary<List<ShowSummary>>(
          future: _shows,
          onRetry: _reload,
          loading: const ShowListSkeleton(hasTabs: true),
          builder: (context, shows) {
            final bookable = shows.where((show) => show.isOnSaleGroup).toList();
            final closed = shows.where((show) => show.isBookingClosed).toList();
            final visible = _sort.apply(_inRange(_inTab(shows)));

            // 빈 이유에 따라 다음 행동이 다르다. 기간 탓이면 기간을 풀면 된다.
            final String emptyMessage;
            if (_range != null) {
              emptyMessage = HomeStrings.emptyInDateRange;
            } else {
              emptyMessage = switch (_selectedTab) {
                _bookableTab => HomeStrings.emptyBookableList,
                _closedTab => HomeStrings.emptyClosedList,
                _ => HomeStrings.emptyAllShowsList,
              };
            }

            return ShowListView(
              shows: visible,
              emptyMessage: emptyMessage,
              header: Column(
                children: [
                  UnderlineTabBar(
                    labels: const [
                      HomeStrings.bookableTab,
                      HomeStrings.closedTab,
                      HomeStrings.allTab,
                    ],
                    // 탭 개수는 날짜로 거른 뒤의 수다. 칩에 기간이 켜져 있는데
                    // 탭 숫자가 그대로면 목록과 숫자가 어긋나 보인다.
                    counts: [
                      _inRange(bookable).length,
                      _inRange(closed).length,
                      _inRange(shows).length,
                    ],
                    selectedIndex: _selectedTab,
                    onSelected: (index) => setState(() => _selectedTab = index),
                  ),
                  ShowFilterBar(
                    range: _range,
                    onDatePressed: () => _openDateSheet(shows),
                    onDateCleared: () => setState(() => _range = null),
                    sort: _sort,
                    onSortSelected: (sort) => setState(() => _sort = sort),
                  ),
                ],
              ),
              // 모든 탭에 상태를 단다. `모두 보기`에는 여러 상태가 섞이고,
              // `예매 가능`에는 예매 중과 매진이 함께 있어 구분이 필요하다.
              badgeBuilder: (show) => BookingStatusBadge(show: show),
              onShowPressed: (show) => Navigator.pushNamed(
                context,
                AppRoutes.showDetail,
                arguments: show.id,
              ),
            );
          },
        ),
      ),
    );
  }
}
