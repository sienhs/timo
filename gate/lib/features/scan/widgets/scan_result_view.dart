import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ScanMetrics.horizontalPadding,
              vertical: 24,
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _ResultIcon(icon: spec.icon),
                const SizedBox(height: 40),
                _ResultCard(title: spec.title, detail: spec.detail),
                const SizedBox(height: 20),
                if (spec.guide != null)
                  Text(
                    spec.guide!,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.onScan,
                    ),
                  ),
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
                        ),
                      ),
                    ],
                  ),
              ],
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
        border: Border.all(
          color: AppColors.onScan,
          width: ScanMetrics.resultIconStroke,
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(ScanMetrics.resultCardRadius),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.displaySmall,
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}

/// 결과 화면의 흰 버튼. 색 바탕 위라 테마의 초록 버튼은 쓸 수 없다.
class _ResultButton extends StatelessWidget {
  const _ResultButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
