import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_detail.dart';

/// 화면 맨 아래 고정 바. [ShowBookingPhase] 에 따라 버튼이 갈린다.
///
/// - 예매 중: `예매하러 가기` 만
/// - 오픈 전: 남은 시간(또는 오픈 일시) + `오픈 알림 및 찜하기`
/// - 서버가 아직 안 열어 줌: `오픈 알림 및 찜하기` 만 - 남은 시간은 안 적는다
/// - 마감·종료·취소: 잠긴 버튼만(`예매가 마감되었습니다` 등)
///
/// 오픈된 공연에는 안내 문구를 얹지 않는다. 공연일은 바로 위 '일시:' 줄에 이미
/// 있어서 같은 날짜가 한 화면에 두 번 찍히고, 버튼 바로 위에 붙은 날짜는
/// 예매와 관련된 마감일처럼 읽힌다. 오픈 전 문구는 남긴다 — 저건 공연일이
/// 아니라 언제부터 누를 수 있는지를 알리는 말이다.
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
    required this.isFavorite,
    required this.onBookPressed,
    required this.onNotifyPressed,
  });

  final ShowDetail detail;
  final DateTime now;

  /// 이 공연을 찜했는가. 오픈 알림을 받는 상태와 같은 말이라
  /// (`ShowDetailStrings.notifyAction` 주석) 알림 버튼이 이 값으로 갈린다.
  final bool isFavorite;

  final VoidCallback onBookPressed;
  final VoidCallback onNotifyPressed;

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
              // 남은 시간은 언제 열리는지 아는 동안에만 적는다. 잠긴 버튼은
              // 이미 이유를 말하고 있고, 서버가 아직 안 열어 준 공연은 열릴
              // 시각을 앱이 모른다 - 그 자리에 0 을 찍으면 멈춘 시계가 된다.
              if (phase == ShowBookingPhase.upcoming) ...[
                _Countdown(
                  text: _upcomingCaption(detail.remainingUntilOpenAt(now)),
                ),
                const SizedBox(height: ShowDetailMetrics.bottomBarGap),
              ],
              _action(phase),
            ],
          ),
        ),
      ),
    );
  }

  /// 상태별 버튼 하나.
  ///
  /// 오픈 전 버튼이 찜 여부에 따라 채움/테두리로 갈린다. 이미 알림을 신청한
  /// 사람에게까지 화면에서 가장 눈에 띄는 버튼으로 '해제' 를 들이밀 이유가
  /// 없어서다.
  Widget _action(ShowBookingPhase phase) {
    // 살 수 없는 공연은 누를 곳이 없다. 버튼을 숨기지 않고 잠근 채 이유를
    // 적는다 — 자리가 비면 왜 예매를 못 하는지 알 길이 없다.
    final locked = _lockedLabel(phase);
    if (locked != null) {
      return FilledButton(onPressed: null, child: Text(locked));
    }
    if (phase == ShowBookingPhase.onSale) {
      return FilledButton(
        onPressed: onBookPressed,
        child: const Text(ShowDetailStrings.bookAction),
      );
    }
    if (isFavorite) {
      return OutlinedButton(
        onPressed: onNotifyPressed,
        child: const Text(ShowDetailStrings.unnotifyAction),
      );
    }
    return FilledButton(
      onPressed: onNotifyPressed,
      child: const Text(ShowDetailStrings.notifyAction),
    );
  }

  /// 버튼을 잠글 단계면 거기 적을 문구, 아니면 null.
  ///
  /// `default` 도 `_` 도 두지 않는다. 그걸 두면 [ShowBookingPhase] 에 단계를
  /// 하나 더 넣어도 조용히 통과해, 잠가야 할 공연에 `예매하러 가기` 가 붙는다.
  /// 빠짐없이 적어 두면 그 순간 컴파일이 깨진다.
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
