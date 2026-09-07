import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/show_summary.dart';
import 'show_poster_card.dart';

/// 카드에 얹을 뱃지를 정한다. 뱃지가 없으면 null 을 준다.
typedef ShowBadgeBuilder = Widget? Function(ShowSummary show, int index);

/// 공연 카드를 가로로 늘어놓는 줄. 오픈 임박·인기 공연이 함께 쓴다.
///
/// 높이를 지정하지 않으려고 ListView 대신 가로 스크롤 + Row 로 짰다. 카드
/// 높이는 포스터 비율과 글자 크기에서 나오는데, ListView 로 가면 그 높이를
/// 바깥에서 숫자로 정해 줘야 해서 시스템 글꼴을 키운 기기에서 잘린다.
/// 한 줄에 들어가는 카드가 열 장 이하라 지연 생성의 이점도 없다.
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
                right: index == shows.length - 1
                    ? 0
                    : HomeMetrics.showCardGap,
              ),
              child: ShowPosterCard(
                show: shows[index],
                badge: buildBadge?.call(shows[index], index),
                onPressed: () => onShowPressed(shows[index]),
              ),
            ),
        ],
      ),
    );
  }
}
