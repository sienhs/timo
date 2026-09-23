import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_detail.dart';

/// 화면 맨 아래 고정 바. [ShowBookingPhase] 에 따라 버튼이 갈린다 — 예매 중은 예매 +
/// 양도 마켓 알림, 오픈 전은 남은 시간(또는 오픈 일시) + 오픈 알림, 서버가 아직 안
/// 열어 준 공연은 오픈 알림만, 마감·종료·취소는 잠긴 버튼만. 매진은 잠그지 않는다.
/// 알림 버튼은 찜과 별개고 두 알림도 서로 따로다. 시각은 뱃지와 같은 [now] 를 받는다.
class ShowDetailBottomBar extends StatelessWidget {
  const ShowDetailBottomBar({
    super.key,
    required this.detail,
    required this.now,
    required this.isOpenAlarmOn,
    required this.isMarketAlarmOn,
    required this.onBookPressed,
    required this.onOpenAlarmPressed,
    required this.onMarketAlarmPressed,
  });

  final ShowDetail detail;
  final DateTime now;

  /// 이 공연의 예매 오픈 알림을 신청했는가.
  final bool isOpenAlarmOn;

  /// 이 공연의 양도 매물 알림을 신청했는가.
  final bool isMarketAlarmOn;

  final VoidCallback onBookPressed;
  final VoidCallback onOpenAlarmPressed;
  final VoidCallback onMarketAlarmPressed;

  @override
  Widget build(BuildContext context) {
    final phase = detail.phaseAt(now);

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
              // 남은 시간은 언제 열리는지 아는 동안에만 적는다. 서버가 아직 안 열어 준
              // 공연은 열릴 시각을 모른다 — 그 자리에 0 을 찍으면 멈춘 시계가 된다.
              if (phase == ShowBookingPhase.upcoming) ...[
                _Countdown(
                  text: _upcomingCaption(detail.remainingUntilOpenAt(now)),
                ),
                const SizedBox(height: ShowDetailMetrics.bottomBarGap),
              ],
              ..._actions(phase),
            ],
          ),
        ),
      ),
    );
  }

  /// 상태별 버튼들. 둘이 서면 예매가 위, 알림이 아래다 — 위에서 아래로 읽는
  /// 순서에서 먼저 만나는 자리를 주 동작인 예매가 갖는다.
  List<Widget> _actions(ShowBookingPhase phase) {
    // 살 수 없는 공연은 누를 곳이 없다. 버튼을 숨기지 않고 잠근 채 이유를
    // 적는다 — 자리가 비면 왜 예매를 못 하는지 알 길이 없다.
    final locked = _lockedLabel(phase);
    if (locked != null) {
      return [FilledButton(onPressed: null, child: Text(locked))];
    }
    if (phase == ShowBookingPhase.onSale) {
      return [
        FilledButton(
          onPressed: onBookPressed,
          child: const Text(ShowDetailStrings.bookAction),
        ),
        const SizedBox(height: ShowDetailMetrics.bottomBarActionGap),
        _marketAlarmButton(),
      ];
    }
    return [_openAlarmButton()];
  }

  /// 오픈 알림 버튼. 신청 여부에 따라 채움/테두리로 갈린다. 아이콘도 글자도
  /// **지금 누르면 일어날 일**을 가리킨다 — 켜진 상태를 그리면 종 아이콘과
  /// '해제하기' 가 서로 반대를 말하게 된다.
  Widget _openAlarmButton() {
    if (isOpenAlarmOn) {
      return OutlinedButton.icon(
        onPressed: onOpenAlarmPressed,
        icon: const Icon(Icons.notifications_off_outlined),
        label: const Text(ShowDetailStrings.unnotifyAction),
      );
    }
    return FilledButton.icon(
      onPressed: onOpenAlarmPressed,
      icon: const Icon(Icons.notifications_none),
      label: const Text(ShowDetailStrings.notifyAction),
    );
  }

  /// 양도 마켓 알림 버튼. 예매 버튼과 나란히 서므로 신청 전에도 테두리다 —
  /// 채운 버튼이 둘이면 어느 쪽이 이 화면의 주된 일인지 흐려진다.
  Widget _marketAlarmButton() => OutlinedButton.icon(
    onPressed: onMarketAlarmPressed,
    icon: Icon(
      isMarketAlarmOn
          ? Icons.notifications_off_outlined
          : Icons.notifications_none,
    ),
    label: Text(
      isMarketAlarmOn
          ? ShowDetailStrings.marketAlarmOffAction
          : ShowDetailStrings.marketAlarmAction,
    ),
  );

  /// 버튼을 잠글 단계면 거기 적을 문구, 아니면 null. `default` 도 `_` 도 두지 않는다 —
  /// [ShowBookingPhase] 에 단계가 늘었을 때 조용히 통과하지 않고 컴파일이 깨지게 한다.
  String? _lockedLabel(ShowBookingPhase phase) => switch (phase) {
    ShowBookingPhase.finished => ShowDetailStrings.closedNotice,
    ShowBookingPhase.canceled => ShowDetailStrings.canceledNotice,
    ShowBookingPhase.bookingClosed => ShowDetailStrings.bookingClosedNotice,
    ShowBookingPhase.onSale ||
    ShowBookingPhase.upcoming ||
    ShowBookingPhase.awaitingOpen => null,
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

/// 오픈까지 남은 시간 한 줄. 시계 아이콘이 앞에 선다.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.schedule,
          size: ShowDetailMetrics.countdownIconSize,
          color: AppColors.primaryPressed,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            // 흰 배경 위 진한 그린(4.98:1). 브랜드 그린(AppColors.primary)은
            // 3.43:1 이라 이 크기 글자에는 못 쓴다.
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: AppColors.primaryPressed),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
