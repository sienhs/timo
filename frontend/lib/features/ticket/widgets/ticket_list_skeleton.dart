import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';
import 'ticket_card.dart';

/// 불러오는 동안 세워 두는 뼈대 카드들. 스피너 대신 카드 모양을 미리 그려 카드가
/// 들어올 때 화면이 덜 흔들리게 한다. 공용 [SkeletonBox] 를 쌓아 만든다.
class TicketListSkeleton extends StatelessWidget {
  const TicketListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: TicketMetrics.horizontalPadding,
        vertical: TicketMetrics.cardGap,
      ),
      itemCount: TicketMetrics.skeletonCardCount,
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return TicketCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: TicketMetrics.posterWidth,
                height: TicketMetrics.posterHeight,
                child: SkeletonBox(radius: TicketMetrics.posterRadius),
              ),
              const SizedBox(width: TicketMetrics.cardPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 160,
                      child: SkeletonBox(radius: 4),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      SizedBox(
                        height: 12,
                        // 줄 길이를 조금씩 달리해야 글자처럼 보인다.
                        width: 140.0 - i * 20,
                        child: const SkeletonBox(radius: 4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TicketMetrics.cardPadding),
          const SizedBox(
            height: TicketMetrics.buttonHeight,
            width: double.infinity,
            child: SkeletonBox(radius: 8),
          ),
        ],
      ),
    );
  }
}
