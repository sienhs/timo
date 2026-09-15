import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_detail.dart';

/// 화면 맨 아래 고정 바. 예매 상태에 따라 안내 한 줄과 버튼이 갈린다.
///
/// - 오픈 전: 남은 시간(또는 오픈 일시) + `오픈 알림 받기`
/// - 오픈 후: 공연일 + `예매하러 가기`
/// - 끝난 공연: 잠긴 버튼만(`종료된 공연입니다`)
///
/// 매진은 잠그지 않는다. 취소표가 돌아올 수 있어 들어가 볼 이유가 있다.
///
/// 시각을 스스로 재지 않고 [now] 를 받는다. 타이머를 여기에 두면 상단 상태
/// 뱃지와 하단 바가 각자 시간을 재게 되어, 오픈 시각을 넘기는 순간 둘 중
/// 하나만 먼저 바뀌는 프레임이 생긴다.
class ShowDetailBottomBar extends StatelessWidget {
  const ShowDetailBottomBar({
    super.key,
    required this.detail,
    required this.now,
    required this.onBookPressed,
    required this.onNotifyPressed,
  });

  final ShowDetail detail;
  final DateTime now;
  final VoidCallback onBookPressed;
  final VoidCallback onNotifyPressed;

  @override
  Widget build(BuildContext context) {
    final finished = _finishedLabel();
    final isOpen = detail.isOpenAt(now);
    final remaining = detail.remainingUntilOpenAt(now);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ShowDetailMetrics.horizontalPadding,
            12,
            ShowDetailMetrics.horizontalPadding,
            12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 끝난 공연에는 날짜를 적지 않는다. 잠긴 버튼이 이미 끝났다고
              // 말하는데 그 위에 날짜만 남으면 무슨 날인지 헷갈린다.
              if (finished == null) ...[
                _Caption(
                  text: isOpen ? detail.dateLabel : _upcomingCaption(remaining),
                  // 시계는 남은 시간을 읽는 데 도움이 되지만, 이미 오픈한
                  // 공연의 날짜 앞에 붙으면 '날이 끝나 간다'로 잘못 읽힌다.
                  showClock: !isOpen,
                ),
                const SizedBox(height: ShowDetailMetrics.bottomBarGap),
              ],
              FilledButton(
                // 끝난 공연은 누를 곳이 없다. 버튼을 숨기지 않고 잠근 채
                // 이유를 적는다 — 자리가 비면 왜 예매를 못 하는지 알 길이 없다.
                onPressed: finished != null
                    ? null
                    : (isOpen ? onBookPressed : onNotifyPressed),
                child: Text(
                  finished ??
                      (isOpen
                          ? ShowDetailStrings.bookAction
                          : ShowDetailStrings.notifyAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 끝난 공연이면 잠긴 버튼에 적을 문구, 아니면 null.
  String? _finishedLabel() => switch (detail.status) {
    ShowStatus.closed => ShowDetailStrings.closedNotice,
    ShowStatus.canceled => ShowDetailStrings.canceledNotice,
    _ => null,
  };

  /// 오픈 전 안내 문구. 하루가 넘게 남으면 초를 세지 않는다 —
  /// `1152:23:14` 는 언제인지 읽히지 않는다.
  String _upcomingCaption(Duration remaining) {
    if (remaining <= ShowDetailMetrics.countdownWindow) {
      return ShowDetailStrings.countdown(remaining);
    }
    return ShowDetailStrings.openAt(detail.ticketOpenAt!);
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text, required this.showClock});

  final String text;
  final bool showClock;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showClock) ...[
          const Icon(
            Icons.schedule,
            size: ShowDetailMetrics.countdownIconSize,
            color: AppColors.primaryPressed,
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            // 흰 배경 위 진한 그린(4.98:1). 브랜드 그린(AppColors.primary)은
            // 3.43:1 이라 이 크기 글자에는 못 쓴다.
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryPressed,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
