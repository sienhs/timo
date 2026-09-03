import 'dart:async';

import 'package:flutter/material.dart';

import '../constants.dart';
import '../../../core/utils/formatters.dart';
import 'primary_action_button.dart';

/// 좌석 선점 남은 시간을 함께 보여주는 결제 버튼.
///
/// 1초마다 갱신되므로 타이머와 상태를 이 위젯 안에 가둔다. 화면 전체가 다시 그려지지 않는다.
class HoldCountdownButton extends StatefulWidget {
  const HoldCountdownButton({
    super.key,
    required this.onPressed,
    this.duration = PaymentConstants.holdDuration,
  });

  /// 남은 시간이 있을 때 눌렀을 때 실행된다. 시간이 끝나면 버튼은 비활성된다.
  final VoidCallback onPressed;

  final Duration duration;

  @override
  State<HoldCountdownButton> createState() => _HoldCountdownButtonState();
}

class _HoldCountdownButtonState extends State<HoldCountdownButton> {
  late Duration _remaining = widget.duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(PaymentConstants.countdownTick, (_) {
      final next = _remaining - PaymentConstants.countdownTick;
      if (next <= Duration.zero) {
        _timer?.cancel();
      }
      setState(() => _remaining = next.isNegative ? Duration.zero : next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining <= Duration.zero;
    return PrimaryActionButton(
      label: '${PaymentConstants.payActionLabel} '
          '(남은 시간 ${formatCountdown(_remaining)})',
      onPressed: isExpired ? null : widget.onPressed,
    );
  }
}
