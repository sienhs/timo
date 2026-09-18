import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/market_hours.dart';
import '../state/resale_api_scope.dart';
import 'market_countdown.dart';

/// 마켓의 다음 경계(닫힘 또는 오픈)까지 남은 시간. 서버 시계로 센다.
///
/// [MarketCountdown] 에 [MarketHours] 를 붙인 것이다. 세는 대상은
/// [MarketHours.nextBoundary] 고, 시계는 기기 시각을 서버 시각으로 옮긴
/// [MarketHours.serverNow] 다. 이 둘을 화면마다 짝지으면 어느 화면 하나가
/// 기기 시계로 세어 다른 화면과 어긋난다.
class MarketHoursCountdown extends StatelessWidget {
  const MarketHoursCountdown({
    super.key,
    required this.hours,
    required this.semanticsLabel,
    this.style,
    this.onElapsed,
    this.clock = DateTime.now,
  });

  final MarketHours hours;
  final String Function(String remaining) semanticsLabel;
  final TextStyle? style;

  /// 경계 시각이 됐을 때. 화면이 서버에 다시 물어 상태를 바꾼다.
  final VoidCallback? onElapsed;

  /// 기기 시각을 읽는 함수. 테스트가 고정할 수 있게 받는다.
  final DateTime Function() clock;

  /// 상단 바 오른쪽에 놓일 때의 글자. 세 화면이 같은 자리에 같은 모양으로 둔다.
  static const appBarStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    return MarketCountdown(
      until: hours.nextBoundary,
      clock: () => hours.serverNow(clock()),
      onElapsed: onElapsed,
      semanticsLabel: semanticsLabel,
      style: style,
    );
  }
}

/// 상단 바의 마켓 마감 카운트다운. 운영 상태를 스스로 받아 온다.
///
/// 매물 목록·구매 확인 화면은 공연 목록이 받아 둔 운영 상태를 넘겨받지
/// 않는다 — 라우트 인자로 실어 나르면 매물 번호 하나만 받던 화면이 운영
/// 상태까지 받아야 하고, 그 값은 화면을 오가는 사이 낡는다. 한 번 더 묻는
/// 쪽이 값도 새롭고 화면도 단순하다.
///
/// 받아 오는 동안, 못 받았을 때, 닫혀 있을 때는 아무것도 그리지 않는다.
/// 남은 시간은 안내일 뿐이라 없어도 화면의 일(목록·결제)은 그대로 된다.
class MarketClosingCountdown extends StatefulWidget {
  const MarketClosingCountdown({
    super.key,
    this.onElapsed,
    this.clock = DateTime.now,
  });

  /// 마감 시각이 됐을 때.
  final VoidCallback? onElapsed;

  final DateTime Function() clock;

  @override
  State<MarketClosingCountdown> createState() => _MarketClosingCountdownState();
}

class _MarketClosingCountdownState extends State<MarketClosingCountdown> {
  MarketHours? _hours;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final hours = await ResaleApiScope.of(context).fetchMarketHours();
      if (mounted) setState(() => _hours = hours);
    } on ApiException {
      // 안내용 값이라 못 받으면 비워 둔다. 화면의 본문은 제 요청의 결과로
      // 따로 실패를 알린다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = _hours;
    if (hours == null || !hours.isOpen) return const SizedBox.shrink();

    return MarketHoursCountdown(
      hours: hours,
      clock: widget.clock,
      onElapsed: widget.onElapsed,
      semanticsLabel: ResaleStrings.openRemainingSemantics,
      style: MarketHoursCountdown.appBarStyle,
    );
  }
}
