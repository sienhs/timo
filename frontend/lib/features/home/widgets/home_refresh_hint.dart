import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/refresh_hint.dart';

/// 아래로 당길 때 목록 위에서 열리는 안내 줄. 스크롤 영역 밖(상단 바와 목록
/// 사이)에 둔다 — 목록의 첫 항목으로 넣으면 당기는 중에 스크롤 위치와 엉킨다.
/// 손을 떼고 새로 고침이 시작될 때 강조 낱말만 한 번 튀어오른다.
class HomeRefreshHint extends StatefulWidget {
  const HomeRefreshHint({
    super.key,
    required this.message,
    required this.visible,
    required this.refreshing,
  });

  final RefreshHint message;

  /// 줄이 열려 있는지. 당기는 중이거나 새로 고치는 중이면 열린다.
  final bool visible;

  /// 새로 고치는 중인지. 이 값이 켜지는 순간(= 손을 떼는 순간) 한 번 튄다.
  final bool refreshing;

  @override
  State<HomeRefreshHint> createState() => _HomeRefreshHintState();
}

class _HomeRefreshHintState extends State<HomeRefreshHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HomeMetrics.refreshJumpDuration,
  );

  /// 0 에서 시작해 1(가장 높은 지점)까지 솟았다가 되돌아온다. 올라갈 때는 짧고
  /// 곧게, 내려올 때는 길게 튕기도록 두 커브를 잇는다.
  late final Animation<double> _jump = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutQuad)),
      weight: 32,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 68,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(HomeRefreshHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 손을 뗀 순간 한 번만 튄다.
    if (widget.refreshing && !oldWidget.refreshing) _startJump();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startJump() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // 본문보다 크고 굵게, 색은 옅게. 옅은 회색은 대비 3.36:1 이라 일반 텍스트
    // 기준에는 못 미치지만 20px 굵은 글씨는 대형 텍스트 기준 3:1 을 넘는다.
    final baseStyle = Theme.of(
      context,
    ).textTheme.headlineSmall!.copyWith(color: AppColors.textSecondary);

    return AnimatedSize(
      duration: HomeMetrics.refreshHintTransition,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        height: widget.visible ? HomeMetrics.refreshHintHeight : 0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HomeMetrics.horizontalPadding,
            ),
            // 강조 낱말을 따로 그리면 스크린 리더가 문구를 토막내 읽는다.
            // 문구 전체를 라벨로 달고 조각들은 의미에서 빼 준다.
            child: Semantics(
              label: widget.message.plainText,
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: widget.message.before),
                      _jumpingHighlight(baseStyle),
                      TextSpan(text: widget.message.after),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: baseStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 브랜드 색으로 강조한 낱말. 이 조각만 움직인다. [WidgetSpan] 으로 넣어
  /// 두 줄이 되어도 글자처럼 줄바꿈에 참여한다.
  InlineSpan _jumpingHighlight(TextStyle baseStyle) {
    return WidgetSpan(
      // 밑선 기준으로 놓아야 튀어오른 뒤에도 글줄이 어긋나지 않는다.
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: AnimatedBuilder(
        animation: _jump,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -_jump.value * HomeMetrics.refreshJumpHeight),
          child: Transform.scale(
            scale: 1 + _jump.value * HomeMetrics.refreshJumpScale,
            child: child,
          ),
        ),
        child: Text(
          widget.message.highlight,
          style: baseStyle.copyWith(color: AppColors.brand),
        ),
      ),
    );
  }
}
