import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/show_summary.dart';
import '../state/home_api_scope.dart';
import '../widgets/show_search_result_tile.dart';

/// 공연 검색. 홈 상단의 검색 바를 누르면 열린다.
///
/// 검색어를 **제출했을 때만** 요청한다. 글자마다 보내면 요청이 글자 수만큼
/// 나가고, 늦게 온 앞 글자의 결과가 뒤 결과를 덮는다. 필터·정렬은 없다 —
/// 요구사항의 검색·필터(#36)는 Could 라 이번엔 키워드만 붙인다.
class ShowSearchScreen extends StatefulWidget {
  const ShowSearchScreen({super.key});

  @override
  State<ShowSearchScreen> createState() => _ShowSearchScreenState();
}

class _ShowSearchScreenState extends State<ShowSearchScreen> {
  final _controller = TextEditingController();

  /// 마지막으로 제출한 검색어. 빈 결과 문구에 되비춰 준다.
  String _keyword = '';

  /// 검색을 아직 안 했으면 null. 안내 문구와 결과 목록을 이걸로 가른다.
  Future<List<ShowSummary>>? _results;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String raw) {
    final keyword = raw.trim();
    if (keyword.isEmpty) return;
    setState(() {
      _keyword = keyword;
      _results = HomeApiScope.of(context).search(keyword);
    });
  }

  void _retry() => _search(_keyword);

  void _openShowDetail(ShowSummary show) {
    Navigator.pushNamed(
      context,
      AppRoutes.showDetail,
      arguments: show.id.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: const InputDecoration(
            hintText: HomeStrings.searchHint,
            border: InputBorder.none,
          ),
        ),
      ),
      body: results == null
          ? const _Message(HomeStrings.searchIdle)
          : AsyncBoundary<List<ShowSummary>>(
              future: results,
              onRetry: _retry,
              builder: (context, shows) => shows.isEmpty
                  ? _Message(HomeStrings.searchEmpty(_keyword))
                  : ListView.builder(
                      itemCount: shows.length,
                      itemBuilder: (context, index) => ShowSearchResultTile(
                        show: shows[index],
                        onPressed: () => _openShowDetail(shows[index]),
                      ),
                    ),
            ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HomeMetrics.horizontalPadding),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
