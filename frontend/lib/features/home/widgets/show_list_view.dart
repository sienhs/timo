import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';
import '../constants.dart';
import '../models/show_summary.dart';
import 'show_banner_card.dart';
import 'show_card_row.dart';

/// 검색 칸 한 줄과 그 아래 공연 카드 목록. 더보기로 들어가는 두 화면(오픈 예정
/// 전체 · 공연 전체)이 함께 쓴다. 검색은 서버에 다시 묻지 않고 받아 둔 목록을
/// 그 자리에서 거른다. 무엇을 받아 올지, 카드를 누르면 어디로 갈지는 화면이 정한다.
class ShowListView extends StatefulWidget {
  const ShowListView({
    super.key,
    required this.shows,
    required this.onShowPressed,
    required this.emptyMessage,
    this.header,
    this.badgeBuilder,
  });

  /// 세울 공연. 탭처럼 화면이 먼저 거른 결과가 온다.
  final List<ShowSummary> shows;

  final ValueChanged<ShowSummary> onShowPressed;

  /// 목록이 비었을 때 적는 말. 검색 중이면 검색어를 되비춘 문구가 대신 나온다 —
  /// "없다" 는 같은 말이라도 아무것도 없는 것과 못 찾은 것은 다음 행동이 다르다.
  final String emptyMessage;

  /// 검색 칸과 목록 사이에 끼울 것. 전체 조회 화면의 탭이 여기 들어간다.
  final Widget? header;

  /// 카드마다 얹을 뱃지. 무엇을 달지는 화면이 정한다.
  final ShowBadgeBuilder? badgeBuilder;

  @override
  State<ShowListView> createState() => _ShowListViewState();
}

class _ShowListViewState extends State<ShowListView> {
  final _controller = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 검색어로 좁힌 목록. 공백만 친 경우는 검색하지 않은 것으로 본다.
  List<ShowSummary> get _matched {
    final needle = _keyword.trim();
    if (needle.isEmpty) return widget.shows;
    return widget.shows.where((show) => show.title.contains(needle)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final matched = _matched;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HomeMetrics.horizontalPadding,
            HomeMetrics.searchFieldTopGap,
            HomeMetrics.horizontalPadding,
            0,
          ),
          child: AppSearchField(
            controller: _controller,
            hintText: HomeStrings.listSearchHint,
            clearLabel: HomeStrings.clearSearch,
            onChanged: (value) => setState(() => _keyword = value),
            onCleared: () => setState(() => _keyword = ''),
          ),
        ),
        ?widget.header,
        Expanded(child: matched.isEmpty ? _empty() : _list(matched)),
      ],
    );
  }

  Widget _empty() {
    final needle = _keyword.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HomeMetrics.horizontalPadding),
        child: Text(
          needle.isEmpty
              ? widget.emptyMessage
              : HomeStrings.searchEmpty(needle),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _list(List<ShowSummary> shows) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        HomeMetrics.horizontalPadding,
        HomeMetrics.sectionTitleGap,
        HomeMetrics.horizontalPadding,
        HomeMetrics.bottomGap,
      ),
      itemCount: shows.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: HomeMetrics.searchCardGap),
        child: SizedBox(
          height: HomeMetrics.searchCardHeight,
          child: ShowBannerCard(
            show: shows[index],
            badge: widget.badgeBuilder?.call(shows[index]),
            onPressed: () => widget.onShowPressed(shows[index]),
          ),
        ),
      ),
    );
  }
}
