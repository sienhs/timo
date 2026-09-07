import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/refresh_hint.dart';

/// 아래로 당길 때 목록 위에서 열리는 안내 줄.
///
/// 스크롤 영역 **밖**(상단 바와 목록 사이)에 둔다. 목록의 첫 항목으로 넣으면
/// 당기는 중에 스크롤 영역의 크기가 바뀌어 스크롤 위치와 엉킨다. 밖에 두면
/// 목록이 그만큼 짧아질 뿐이다.
///
/// 손을 떼고 새로 고침이 시작될 때 강조 낱말만 한 번 통 튀어오른다. 당김이
/// 시작될 때 튀게 하면 아직 놓을지 말지 모르는 상태에서 반응해 버리고, 글줄
/// 전체를 계속 흔들면 읽는 데 방해가 된다.
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

  /// 0 에서 시작해 1(가장 높은 지점)까지 솟았다가 되돌아온다.
  ///
  /// 올라갈 때는 짧고 곧게, 내려올 때는 길게 튕기면서 — 이게 '뾰잉' 하는
  /// 느낌을 만든다. 한 커브로는 올라갈 때도 튕겨서 출발이 뭉개진다.
  late final Animation<double> _jump = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(
        CurveTween(curve: Curves.easeOutQuad),
      ),
      weight: 32,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(
        CurveTween(curve: Curves.elasticOut),
      ),
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
    // 화면을 대표하는 한마디라 본문보다 크고 굵게 가되, 색은 옅게 둬서
    // 콘텐츠보다 앞서지 않게 한다.
    //
    // 옅은 회색과 흰 배경의 대비는 3.36:1, 브랜드 색은 3.43:1 이다. 일반
    // 텍스트 기준(4.5:1)에는 둘 다 미달하지만 20px 굵은 글씨는 WCAG 의
    // 대형 텍스트(18.66px 이상 bold) 기준 3:1 을 충족한다. 크기를 줄이려면
    // 색을 함께 진하게 가야 한다.
    final baseStyle = Theme.of(context).textTheme.headlineSmall!.copyWith(
      color: AppColors.textSecondary,
    );

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

  /// 브랜드 색으로 강조한 낱말. 이 조각만 움직인다.
  ///
  /// [WidgetSpan] 으로 넣는다. 문구가 길어져 두 줄이 되어도 낱말이 글줄
  /// 안에서 자연스럽게 흐르려면 글자처럼 줄바꿈에 참여해야 한다.
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
