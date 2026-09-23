import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/show_detail.dart';

/// 화면 맨 아래 고정 바. [ShowBookingPhase] 에 따라 버튼이 갈린다 — 예매 중은 예매 +
/// 양도 마켓 알림, 오픈 전은 남은 시간(또는 오픈 일시) + 오픈 알림, 서버가 아직 안
/// 열어 준 공연은 오픈 알림만, 마감·종료·취소는 잠긴 버튼만. 매진은 잠그지 않는다.
/// 알림 버튼은 찜과 별개고 두 알림도 서로 따로다. 시각은 뱃지와 같은 [now] 를 받는다.
///
/// 바를 끌어내리면 손잡이만 남기고 접히고, 끌어올리거나 손잡이를 누르면 다시 펴진다.
/// 버튼 둘이 본문을 꽤 가리므로 상세를 넓게 읽고 싶을 때 치워 둔다.
class ShowDetailBottomBar extends StatefulWidget {
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
  State<ShowDetailBottomBar> createState() => _ShowDetailBottomBarState();
}

class _ShowDetailBottomBarState extends State<ShowDetailBottomBar>
    with SingleTickerProviderStateMixin {
  /// 0 이면 접힘, 1 이면 펼침. 끄는 동안에는 손가락을 따라 그 사이 값을 가진다.
  late final AnimationController _expansion = AnimationController(
    vsync: this,
    value: 1,
  );

  /// 버튼은 바가 절반쯤 내려가면 이미 다 흐려져 있게 한다. 끝까지 보이다가
  /// 잘려 나가면 버튼이 바닥에 끼인 것처럼 보인다.
  late final Animation<double> _contentOpacity = CurvedAnimation(
    parent: _expansion,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  /// 손을 떼면 향하는 쪽. 끄는 도중의 값이 아니라 도착할 상태라 손잡이 이름표가 이걸 본다.
  bool _expanded = true;

  /// 버튼 묶음의 높이. 끈 거리를 펼침 비율로 바꾸고 접힌 높이를 정하는 데 쓴다.
  /// 그리는 도중에는 잴 수 없어 레이아웃이 끝난 뒤 [_MeasureHeight] 가 알려 준다.
  double _contentHeight = 0;

  void _onContentMeasured(double height) {
    if (mounted && height != _contentHeight) {
      setState(() => _contentHeight = height);
    }
  }

  /// 접혔을 때 손잡이 줄의 높이. 펼친 바의 1/3 쯤 남긴다 — 얇게 남기면 올리려던
  /// 손길이 화면 맨 아래 시스템 제스처(홈으로 나가기)에 먹힌다. 아래 여백
  /// ([bottomInset])은 접어도 그대로 있으므로 그만큼 빼고 잰다.
  double _collapsedHandleHeight(double bottomInset) {
    final expanded =
        ShowDetailMetrics.bottomBarHandleHeight + _contentHeight + bottomInset;
    return math.max(
      ShowDetailMetrics.bottomBarCollapsedMinHeight,
      expanded * ShowDetailMetrics.bottomBarCollapsedFraction - bottomInset,
    );
  }

  /// 펼침 비율이 1 바뀔 때 바 높이가 바뀌는 양. 버튼 묶음이 사라지는 만큼
  /// 손잡이 줄이 커지므로 그 차이다.
  double get _travel =>
      _contentHeight +
      ShowDetailMetrics.bottomBarHandleHeight -
      _collapsedHandleHeight(MediaQuery.viewPaddingOf(context).bottom);

  @override
  void dispose() {
    _expansion.dispose();
    super.dispose();
  }

  /// [expand] 쪽으로 스프링을 태워 보낸다. [velocity] 는 펼침 비율 기준(1/s)이다 —
  /// 튕긴 속도를 이어받아야 손을 뗀 순간 바가 멈칫하지 않는다.
  void _settle({required bool expand, double velocity = 0}) {
    setState(() => _expanded = expand);
    final target = expand ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _expansion.value = target;
      return;
    }
    // 스프링은 목표에 아주 가까워지면 멈추므로 끝나면 정확히 붙여 둔다. 중간에
    // 다시 잡혀 멈춘 경우에는 이 future 가 끝나지 않아 붙이지 않는다.
    _expansion
        .animateWith(
          SpringSimulation(
            ShowDetailMetrics.bottomBarSpring,
            _expansion.value,
            target,
            velocity,
          ),
        )
        .then((_) => _expansion.value = target);
  }

  void _toggle() => _settle(expand: !_expanded);

  void _onDragStart(DragStartDetails _) => _expansion.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    final height = _travel;
    if (height <= 0) return;
    // 아래로 끌면(delta > 0) 접힌다.
    _expansion.value -= details.primaryDelta! / height;
  }

  void _onDragEnd(DragEndDetails details) {
    final height = _travel;
    final velocity = details.primaryVelocity ?? 0;
    final expand = velocity.abs() > ShowDetailMetrics.bottomBarFlingVelocity
        ? velocity < 0
        : _expansion.value >= 0.5;
    _settle(expand: expand, velocity: height <= 0 ? 0 : -velocity / height);
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.detail.phaseAt(widget.now);

    // 버튼을 누르는 탭과 바를 끄는 드래그가 한 자리에서 겨룬다. 손가락이 세로로
    // 움직이면 드래그가 이기고, 그대로 떼면 버튼 탭으로 간다.
    return GestureDetector(
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShowDetailMetrics.bottomBarRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 16,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _expansion,
                builder: (context, _) => _Handle(
                  progress: _expansion.value,
                  height: lerpDouble(
                    _collapsedHandleHeight(
                      MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    ShowDetailMetrics.bottomBarHandleHeight,
                    _expansion.value,
                  )!,
                  expanded: _expanded,
                  onTap: _toggle,
                ),
              ),
              SizeTransition(
                sizeFactor: _expansion,
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: _contentOpacity,
                  child: _MeasureHeight(
                    onChanged: _onContentMeasured,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        ShowDetailMetrics.horizontalPadding,
                        0,
                        ShowDetailMetrics.horizontalPadding,
                        12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 남은 시간은 언제 열리는지 아는 동안에만 적는다. 서버가 아직
                          // 안 열어 준 공연은 열릴 시각을 모른다 — 그 자리에 0 을 찍으면
                          // 멈춘 시계가 된다.
                          if (phase == ShowBookingPhase.upcoming) ...[
                            _Countdown(
                              text: _upcomingCaption(
                                widget.detail.remainingUntilOpenAt(widget.now),
                              ),
                            ),
                            const SizedBox(
                              height: ShowDetailMetrics.bottomBarGap,
                            ),
                          ],
                          ..._actions(phase),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
          onPressed: widget.onBookPressed,
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
    if (widget.isOpenAlarmOn) {
      return OutlinedButton.icon(
        onPressed: widget.onOpenAlarmPressed,
        icon: const Icon(Icons.notifications_off_outlined),
        label: const Text(ShowDetailStrings.unnotifyAction),
      );
    }
    return FilledButton.icon(
      onPressed: widget.onOpenAlarmPressed,
      icon: const Icon(Icons.notifications_none),
      label: const Text(ShowDetailStrings.notifyAction),
    );
  }

  /// 양도 마켓 알림 버튼. 예매 버튼과 나란히 서므로 신청 전에도 테두리다 —
  /// 채운 버튼이 둘이면 어느 쪽이 이 화면의 주된 일인지 흐려진다.
  Widget _marketAlarmButton() => OutlinedButton.icon(
    onPressed: widget.onMarketAlarmPressed,
    icon: Icon(
      widget.isMarketAlarmOn
          ? Icons.notifications_off_outlined
          : Icons.notifications_none,
    ),
    label: Text(
      widget.isMarketAlarmOn
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
    return ShowDetailStrings.openAt(widget.detail.ticketOpenAt!);
  }
}

/// 바 위쪽 손잡이. 화살표가 누르면 갈 방향을 가리킨다 — 펼쳐져 있으면 아래,
/// 접혀 있으면 위. 끄는 동안에는 바가 내려간 만큼 따라 돌고, 접힐수록 줄이 커진다.
class _Handle extends StatelessWidget {
  const _Handle({
    required this.progress,
    required this.height,
    required this.expanded,
    required this.onTap,
  });

  /// 펼침 비율. 1 이 펼침, 0 이 접힘.
  final double progress;
  final double height;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded
          ? ShowDetailStrings.collapseBottomBar
          : ShowDetailStrings.expandBottomBar,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Center(
            child: Transform.rotate(
              // 펼침(1)에서 아래, 접힘(0)에서 위(반 바퀴).
              angle: (1 - progress) * math.pi,
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 자식의 높이가 바뀌면 레이아웃이 끝난 뒤 알려 준다. [SizeTransition] 이 바깥을
/// 줄여도 자식은 제 높이로 놓이므로 접힌 동안에도 펼친 높이가 잡힌다.
class _MeasureHeight extends SingleChildRenderObjectWidget {
  const _MeasureHeight({required this.onChanged, required super.child});

  final ValueChanged<double> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureHeight(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureHeight renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _RenderMeasureHeight extends RenderProxyBox {
  _RenderMeasureHeight(this.onChanged);

  ValueChanged<double> onChanged;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    // 레이아웃 도중에 setState 를 부를 수 없어 프레임이 끝난 뒤로 미룬다.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(height));
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
