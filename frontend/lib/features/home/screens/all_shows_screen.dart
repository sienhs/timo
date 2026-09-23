import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/underline_tab_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/show_summary.dart';
import '../state/home_api_scope.dart';
import '../widgets/show_list_app_bar.dart';
import '../widgets/show_list_skeleton.dart';
import '../widgets/show_list_view.dart';

/// 공연 전체 조회. 홈의 "인기 공연" 더보기로 들어온다.
///
/// 서버에서 상태로 거르지 않고 다 받아 와서, 탭으로 나눠 본다 —
/// `예매 가능` 은 예매를 앞두었거나 진행 중인 공연만, `모두 보기` 는 끝난
/// 공연까지 그대로다. 기본은 예매 가능이다. 눌러도 예매가 안 되는 공연이
/// 먼저 보이면 목록을 훑는 값이 떨어진다.
///
/// 탭을 서버 요청으로 가르지 않는 이유는 두 가지다. 서버의 `status` 는 값
/// 하나만 받아 "오픈 예정 또는 예매중" 을 한 번에 물을 수 없고, 한 번에 다
/// 받아 두면 탭을 오갈 때마다 기다리지 않아도 된다.
class AllShowsScreen extends StatefulWidget {
  const AllShowsScreen({super.key});

  @override
  State<AllShowsScreen> createState() => _AllShowsScreenState();
}

class _AllShowsScreenState extends State<AllShowsScreen> {
  /// 탭 순서. 화면이 이 순서로만 가르므로 상수로 둔다.
  static const _bookableTab = 0;

  late Future<List<ShowSummary>> _shows;
  int _selectedTab = _bookableTab;

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
            final bookable = shows
                .where((show) => show.isOpenOrUpcoming)
                .toList();
            final isBookableTab = _selectedTab == _bookableTab;
            return ShowListView(
              shows: isBookableTab ? bookable : shows,
              emptyMessage: isBookableTab
                  ? HomeStrings.emptyBookableList
                  : HomeStrings.emptyAllShowsList,
              header: UnderlineTabBar(
                labels: const [HomeStrings.bookableTab, HomeStrings.allTab],
                counts: [bookable.length, shows.length],
                selectedIndex: _selectedTab,
                onSelected: (index) => setState(() => _selectedTab = index),
              ),
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
