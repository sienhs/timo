import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../constants.dart';
import '../models/verification_result.dart';

/// 검증 결과 전체 화면. 카메라 자리를 통째로 덮는다.
///
/// 색·아이콘·문구 셋을 항상 함께 바꾼다 — 색만으로 구분하면 색약 운영자와
/// 햇빛 아래에서 읽을 수 없다.
///
/// - [Admitted]: 초록, 체크. 버튼 없음. 잠시 뒤 스스로 닫히고 눌러도 닫힌다.
/// - [Rejected]: 빨강, X, 사유. 운영자가 읽고 버튼으로 닫는다.
/// - [Undetermined]: 회색, 느낌표, 오류 문구. 마찬가지로 버튼으로 닫는다.
///
/// 결과가 어디서 왔는지는 모른다. 결과 객체와 닫기 콜백만 받는다.
class ScanResultView extends StatelessWidget {
  const ScanResultView({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  final VerificationResult result;

  /// 결과를 닫고 다음 스캔으로 돌아갈 때.
  ///
  /// 와이어프레임의 '다음 QR' 과 '확인' 은 지금 둘 다 이것을 부른다. 두 버튼의
  /// 역할이 갈리면(예: '확인' 은 결과를 유지한 채 기록만 남김) 그때 콜백을 나눈다.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final spec = _SpecOf(result);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      label: ScanStrings.resultSemantics(spec.title, spec.detail),
      child: GestureDetector(
        // 허용 화면은 아무 데나 눌러도 닫힌다. 버튼이 없는데 1.5초를 기다리기
        // 싫은 운영자를 위한 것이다. 거절은 버튼으로만 — 실수로 넘기면 안 된다.
        onTap: spec.hasButtons ? null : onDismiss,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: spec.color,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ScanMetrics.horizontalPadding,
                vertical: 24,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _ResultIcon(icon: spec.icon),
                  const SizedBox(height: 36),
                  _ResultCard(
                    title: spec.title,
                    detail: spec.detail,
                    color: spec.color,
                  ),
                  if (spec.guide != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: AppColors.onScanMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          spec.guide!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.onScan,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(flex: 3),
                  if (spec.hasButtons)
                    Row(
                      children: [
                        Expanded(
                          child: _ResultButton(
                            label: ScanStrings.nextQr,
                            onPressed: onDismiss,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ResultButton(
                            label: ScanStrings.confirm,
                            onPressed: onDismiss,
                            filled: false,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 결과 종류별 색·아이콘·문구. 한 곳에서 정해야 셋이 어긋나지 않는다.
class _SpecOf {
  factory _SpecOf(VerificationResult result) => switch (result) {
    Admitted() => const _SpecOf._(
      color: AppColors.admitted,
      icon: Icons.check_rounded,
      title: ScanStrings.admitted,
      detail: '',
      guide: null,
      hasButtons: false,
    ),
    Rejected(:final reason) => _SpecOf._(
      color: AppColors.rejected,
      icon: Icons.close_rounded,
      title: ScanStrings.rejected,
      detail: reason.label,
      guide: ScanStrings.rejectedGuide,
      hasButtons: true,
    ),
    Undetermined(:final message) => _SpecOf._(
      color: AppColors.undetermined,
      icon: Icons.priority_high_rounded,
      title: ScanStrings.undetermined,
      detail: message,
      guide: ScanStrings.undeterminedGuide,
      hasButtons: true,
    ),
  };

  const _SpecOf._({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
    required this.guide,
    required this.hasButtons,
  });

  final Color color;
  final IconData icon;
  final String title;

  /// 카드 안 두 번째 줄. 비어 있으면 안 그린다.
  final String detail;

  /// 카드 아래 운영자용 안내. 없으면 null.
  final String? guide;
  final bool hasButtons;
}

/// 결과 아이콘. 반투명 흰 원 위에 흰 아이콘. 테두리만 있는 원보다 멀리서
/// 덩어리로 읽힌다.
class _ResultIcon extends StatelessWidget {
  const _ResultIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ScanMetrics.resultIconSize,
      height: ScanMetrics.resultIconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.onScan.withValues(alpha: 0.18),
        border: Border.all(
          color: AppColors.onScan.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        size: ScanMetrics.resultIconSize * 0.55,
        color: AppColors.onScan,
      ),
    );
  }
}

/// 흰 카드. 제목은 결과 색으로 적어 배경과 짝이 맞게 한다 — 카드가 흰색이라
/// 제목까지 검정이면 무슨 결과인지 카드만 봐서는 모른다.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.detail,
    required this.color,
  });

  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.cardPadding,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ScanMetrics.resultCardRadius),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(color: color),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 결과 화면의 버튼. 색 바탕 위라 테마의 초록 버튼은 쓸 수 없다.
/// [filled] 면 흰 채움(주 동작), 아니면 흰 테두리(보조).
class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    if (!filled) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onScan,
          side: BorderSide(color: AppColors.onScan.withValues(alpha: 0.7)),
          textStyle: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.onScan),
        ),
        child: Text(label),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      child: Text(label),
    );
  }
}
