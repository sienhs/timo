import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/show_summary.dart';
import 'show_poster_card.dart';

/// 카드에 얹을 뱃지를 정한다. 뱃지가 없으면 null 을 준다.
typedef ShowBadgeBuilder = Widget? Function(ShowSummary show);

/// 공연 카드를 가로로 늘어놓는 줄. 오픈 예정·인기 공연이 함께 쓴다. ListView 로
/// 가면 카드 높이를 바깥에서 숫자로 정해 줘야 해 시스템 글꼴을 키운 기기에서
/// 잘리므로, 가로 스크롤 + Row 로 짜 높이가 내용에서 나오게 한다.
class ShowCardRow extends StatelessWidget {
  const ShowCardRow({
    super.key,
    required this.shows,
    required this.onShowPressed,
    this.badgeBuilder,
  });

  final List<ShowSummary> shows;
  final ValueChanged<ShowSummary> onShowPressed;
  final ShowBadgeBuilder? badgeBuilder;

  @override
  Widget build(BuildContext context) {
    final buildBadge = badgeBuilder;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: HomeMetrics.horizontalPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < shows.length; index++)
            Padding(
              padding: EdgeInsets.only(
                right: index == shows.length - 1 ? 0 : HomeMetrics.showCardGap,
              ),
              child: ShowPosterCard(
                show: shows[index],
                badge: buildBadge?.call(shows[index]),
                onPressed: () => onShowPressed(shows[index]),
              ),
            ),
        ],
      ),
    );
  }
}
