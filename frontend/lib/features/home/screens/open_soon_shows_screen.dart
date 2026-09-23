import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/show_summary.dart';
import '../state/home_api_scope.dart';
import '../widgets/show_list_app_bar.dart';
import '../widgets/show_list_skeleton.dart';
import '../widgets/show_list_view.dart';

/// 오픈 예정 공연 전체. 홈의 "티켓 오픈 예정" 더보기로 들어온다.
///
/// 홈의 가로 한 줄이 앞 몇 건만 보여 주는 자리라면, 여기는 그 나머지까지
/// 오픈이 이른 순으로 늘어놓는 자리다. 조건은 홈과 같고 개수만 다르다
/// ([HomeApi.fetchTicketOpenAll]).
class OpenSoonShowsScreen extends StatefulWidget {
  const OpenSoonShowsScreen({super.key});

  @override
  State<OpenSoonShowsScreen> createState() => _OpenSoonShowsScreenState();
}

class _OpenSoonShowsScreenState extends State<OpenSoonShowsScreen> {
  late Future<List<ShowSummary>> _shows;

  @override
  void initState() {
    super.initState();
    _shows = HomeApiScope.of(context).fetchTicketOpenAll();
  }

  void _reload() {
    setState(() {
      _shows = HomeApiScope.of(context).fetchTicketOpenAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const ShowListAppBar(title: HomeStrings.openSoonListTitle),
      body: SafeArea(
        bottom: false,
        child: AsyncBoundary<List<ShowSummary>>(
          future: _shows,
          onRetry: _reload,
          loading: const ShowListSkeleton(),
          builder: (context, shows) {
            // 홈의 오픈 예정 줄과 같은 기준으로 한 번 더 거른다. 서버가
            // `status` 로 걸러 주지만 오픈 시각이 지나도 상태가 밀리지 않은
            // 공연이 섞여 온다 — [ShowSummary.opensAfter] 주석 참고.
            final now = DateTime.now();
            return ShowListView(
              shows: shows.where((show) => show.opensAfter(now)).toList(),
              emptyMessage: HomeStrings.emptyOpenSoonList,
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
