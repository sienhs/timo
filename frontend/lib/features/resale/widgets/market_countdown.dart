import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../constants.dart';

/// 어떤 시각까지 남은 시간을 1초마다 다시 그리는 글자. 타이머와 상태를 이
/// 위젯 안에 가두므로 화면 전체가 1초마다 다시 그려지지 않는다. [builder] 를
/// 주면 남은 시간 글자를 원하는 모양으로 감싸고, 안 주면 [style] 로 글자만 그린다.
class MarketCountdown extends StatefulWidget {
  const MarketCountdown({
    super.key,
    required this.until,
    required this.semanticsLabel,
    this.style,
    this.builder,
    this.onElapsed,
    this.clock = DateTime.now,
  });

  /// 세는 대상이 되는 시각.
  final DateTime until;

  /// 남은 시간 글자를 화면 읽기 프로그램용 문장으로 바꾼다. `03:22:12` 만
  /// 읽어 주면 그게 무엇까지의 시간인지 알 수 없다.
  final String Function(String remaining) semanticsLabel;

  final TextStyle? style;

  /// 남은 시간 글자를 받아 위젯을 만든다. 없으면 글자만 그린다.
  final Widget Function(BuildContext context, String remaining)? builder;

  /// 0 이 됐을 때 한 번 불린다. 마켓이 닫히거나 열리는 순간 화면이 다시
  /// 판정하게 하는 데 쓴다.
  final VoidCallback? onElapsed;

  /// 지금 시각을 읽는 함수. 테스트가 시각을 고정할 수 있게 받는다.
  final DateTime Function() clock;

  @override
  State<MarketCountdown> createState() => _MarketCountdownState();
}

class _MarketCountdownState extends State<MarketCountdown> {
  late Duration _remaining = _remainingFromNow();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant MarketCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 세는 대상이 바뀌면(마켓이 닫혀 다음 오픈을 세게 됐다) 처음부터 다시 센다.
    if (widget.until != oldWidget.until) {
      _timer?.cancel();
      setState(() => _remaining = _remainingFromNow());
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_remaining <= Duration.zero) return;
    _timer = Timer.periodic(ResaleMetrics.countdownTick, (_) {
      final next = _remainingFromNow();
      if (next <= Duration.zero) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);
        widget.onElapsed?.call();
        return;
      }
      setState(() => _remaining = next);
    });
  }

  /// 흐른 시간을 빼는 대신 매번 시계를 다시 읽는다. 앱이 잠들어 타이머가
  /// 건너뛴 만큼도 따라잡아야, 화면을 다시 켰을 때 남은 시간이 맞는다.
  Duration _remainingFromNow() {
    final left = widget.until.difference(widget.clock());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = formatCountdownWithHours(_remaining);
    final builder = widget.builder;

    // 감싸 준 위젯(결제 버튼 등)은 제 이름을 스스로 말한다. 여기서 한 번 더
    // 덮으면 버튼이라는 것도, 눌리는 것도 읽히지 않는다.
    if (builder != null) return builder(context, remaining);

    return Semantics(
      label: widget.semanticsLabel(remaining),
      excludeSemantics: true,
      child: Text(remaining, style: widget.style),
    );
  }
}
