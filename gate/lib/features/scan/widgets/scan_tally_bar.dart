import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/scan_tally.dart';

/// 카메라 화면 아래에 깔리는 집계 막대. 총 스캔 · 정상 입장 · 거절/오류.
///
/// 이 단말이 앱을 켠 뒤 찍은 것만 센다([ScanTally] 주석). 화면에 '완료율' 처럼
/// 보이는 값을 두지 않는 이유이기도 하다 — 전체 몇 명 중 몇 명인지는 서버만
/// 알고, 여기 숫자로 그걸 짐작하게 하면 운영자가 잘못된 판단을 한다.
class ScanTallyBar extends StatelessWidget {
  const ScanTallyBar({super.key, required this.tally});

  final ScanTally tally;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ScanMetrics.horizontalPadding,
            0,
            ScanMetrics.horizontalPadding,
            ScanMetrics.counterBarInset,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.scanPanel,
              borderRadius: BorderRadius.circular(
                ScanMetrics.counterBarRadius,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: _TallyCell(
                    label: ScanStrings.tallyTotal,
                    value: tally.total,
                  ),
                ),
                Expanded(
                  child: _TallyCell(
                    label: ScanStrings.tallyAdmitted,
                    value: tally.admitted,
                    dot: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _TallyCell(
                    label: ScanStrings.tallyRejected,
                    value: tally.rejected,
                    dot: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 칸 하나. 위에 이름, 아래에 숫자.
///
/// 숫자를 아래에 크게 두는 것은 서서 내려다보는 자세 때문이다. 이름은 한 번
/// 읽으면 되고 이후로는 숫자만 본다.
class _TallyCell extends StatelessWidget {
  const _TallyCell({required this.label, required this.value, this.dot});

  final String label;
  final int value;

  /// 이름 앞의 점. 없으면 안 그린다(총계).
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dotColor = dot;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (dotColor != null) ...[
              _StatusDot(color: dotColor),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: AppColors.onScanMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: textTheme.titleLarge?.copyWith(color: AppColors.onScan),
        ),
      ],
    );
  }
}

/// 이름 앞에 찍는 작은 원. 색만으로 구분하지 않도록 언제나 글자와 함께 쓴다.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ScanMetrics.statusDotSize,
      height: ScanMetrics.statusDotSize,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
