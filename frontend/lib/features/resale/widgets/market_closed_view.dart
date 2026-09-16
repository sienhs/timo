import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../constants.dart';
import '../models/market_hours.dart';
import 'market_countdown.dart';

/// 마켓이 닫혀 있을 때의 본문. 다음 오픈까지 남은 시간을 센다.
///
/// 목록 자리를 비워 두고 안내만 두는 이유는, 닫혀 있는 동안에는 매물을 아예
/// 보여 주지 않기로 했기 때문이다. 살 수 없는 매물을 늘어놓으면 눌러 보고서야
/// 닫힌 것을 알게 된다.
///
/// 등록은 닫혀 있어도 된다. 그 안내와 버튼은 화면 아래(`ResaleBottomBar`)가
/// 맡는다 — 이 위젯은 가운데 안내만 그린다.
class MarketClosedView extends StatelessWidget {
  const MarketClosedView({
    super.key,
    required this.hours,
    required this.onOpened,
    this.clock = DateTime.now,
  });

  final MarketHours hours;

  /// 오픈 시각이 됐을 때. 화면이 다시 판정해 목록으로 바뀐다.
  final VoidCallback onOpened;

  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ResaleMetrics.horizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TimoMascot.sad(size: 150),
            const SizedBox(height: 20),
            const Text(
              ResaleStrings.closedTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ResaleStrings.closedNextOpen(MarketHours.opensAtLabel),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            MarketCountdown(
              until: hours.nextBoundary,
              clock: clock,
              onElapsed: onOpened,
              semanticsLabel: ResaleStrings.closeRemainingSemantics,
              style: const TextStyle(
                fontSize: ResaleMetrics.closedCountdownFontSize,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
