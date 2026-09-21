import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/utils/formatters.dart';
import '../constants.dart';
import '../models/verification_result.dart';

/// 검증 결과 전체 화면. 카메라 자리를 통째로 덮는다.
///
/// 색·아이콘·문구 셋을 항상 함께 바꾼다 — 색만으로 구분하면 색약 운영자와
/// 햇빛 아래에서 읽을 수 없다.
///
/// - [Admitted]: 초록, 체크. 잠시 뒤 스스로 닫히고, 아무 데나 눌러도·버튼으로도 닫힌다
/// - [Rejected]: 빨강, X, 사유. 운영자가 읽고 **버튼으로만** 닫는다
/// - [Undetermined]: 회색, 느낌표, 오류 문구. 마찬가지로 버튼으로만
///
/// 결과가 어디서 왔는지는 모른다. 결과 객체와 시각, 닫기 콜백만 받는다.
class ScanResultView extends StatelessWidget {
  const ScanResultView({
    super.key,
    required this.result,
    required this.verifiedAt,
    required this.onDismiss,
  });

  final VerificationResult result;

  /// 이 결과를 받은 시각. 카드의 '검표 완료 시각' 에 적는다.
  ///
  /// 화면이 `DateTime.now()` 를 직접 부르지 않는다 — 결과가 뜬 순간과 카드를
  /// 다시 그리는 순간이 다르면 적힌 시각이 슬금슬금 움직인다.
  final DateTime verifiedAt;

  /// 결과를 닫고 다음 스캔으로 돌아갈 때.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final spec = _SpecOf(result);
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      liveRegion: true,
      label: ScanStrings.resultSemantics(spec.title, spec.detail),
      child: GestureDetector(
        // 허용 화면은 아무 데나 눌러도 닫힌다. 1.5초를 기다리기 싫은 운영자를
        // 위한 것이다. 거절은 버튼으로만 — 실수로 넘기면 안 된다.
        onTap: spec.dismissOnTap ? onDismiss : null,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: spec.color,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ScanMetrics.horizontalPadding,
                vertical: 20,
              ),
              // 가운데 덩어리는 자리가 모자라면 스크롤되고, 남으면 가운데에
              // 선다. 버튼은 어느 쪽이든 아래에 붙어 있어야 한다 — 운영자가
              // 누를 자리가 결과 길이에 따라 움직이면 안 된다.
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ResultIcon(icon: spec.icon),
                            if (spec.pill != null) ...[
                              const SizedBox(height: 20),
                              _ResultPill(
                                label: spec.pill!,
                                color: spec.color,
                              ),
                            ],
                            const SizedBox(height: 28),
                            _ResultCard(
                              title: spec.title,
                              detail: spec.detail,
                              color: spec.color,
                              verifiedAt: verifiedAt,
                            ),
                            if (spec.guide != null) ...[
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: AppColors.onScanMuted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      spec.guide!,
                                      textAlign: TextAlign.center,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: AppColors.onScan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ConfirmButton(onPressed: onDismiss),
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
      pill: ScanStrings.admittedPill,
      title: ScanStrings.admitted,
      detail: ScanStrings.admittedDetail,
      guide: null,
      dismissOnTap: true,
    ),
    // '중복 스캔 감지' 는 이미 입장한 티켓일 때만 붙인다. 만료·위조와 섞이면
    // 운영자가 "아까 들어간 사람" 과 "처음 보는 QR" 을 구분 못 한다.
    Rejected(:final reason) => _SpecOf._(
      color: AppColors.rejected,
      icon: Icons.close_rounded,
      pill: reason == RejectReason.alreadyUsed
          ? ScanStrings.duplicatePill
          : null,
      title: ScanStrings.rejected,
      detail: reason.label,
      guide: ScanStrings.rejectedGuide,
      dismissOnTap: false,
    ),
    Undetermined(:final message) => _SpecOf._(
      color: AppColors.undetermined,
      icon: Icons.priority_high_rounded,
      pill: null,
      title: ScanStrings.undetermined,
      detail: message,
      guide: ScanStrings.undeterminedGuide,
      dismissOnTap: false,
    ),
  };

  const _SpecOf._({
    required this.color,
    required this.icon,
    required this.pill,
    required this.title,
    required this.detail,
    required this.guide,
    required this.dismissOnTap,
  });

  final Color color;
  final IconData icon;

  /// 아이콘 아래 작은 알약. 없으면 안 그린다.
  final String? pill;

  final String title;

  /// 카드 안 둘째 줄. 비어 있으면 안 그린다.
  final String detail;

  /// 카드 아래 운영자용 안내. 없으면 null.
  final String? guide;

  /// 바탕을 눌러도 닫히는지.
  final bool dismissOnTap;
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

/// 아이콘 아래 알약. 흰 바탕에 결과 색 글자라, 색 바탕 위에서 한 덩어리로 뜬다.
class _ResultPill extends StatelessWidget {
  const _ResultPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.onScan.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(ScanMetrics.pillRadius),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

/// 흰 카드. 제목은 결과 색으로 적어 배경과 짝이 맞게 한다 — 카드가 흰색이라
/// 제목까지 검정이면 무슨 결과인지 카드만 봐서는 모른다.
///
/// 아래쪽 정보 줄은 지금 '검표 완료 시각' 하나뿐이다. 앱이 시계만 보고 적을 수
/// 있는 유일한 값이기 때문이다. 좌석·예매자·최초 입장 기록은 서버가 응답에
/// 실어 주면 [_InfoRow] 를 더 쌓는 것으로 끝난다 — 이 카드의 모양은 안 바뀐다.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.detail,
    required this.color,
    required this.verifiedAt,
  });

  final String title;
  final String detail;
  final Color color;
  final DateTime verifiedAt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.cardPadding,
        vertical: 24,
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
            const SizedBox(height: 10),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _InfoRow(
            label: ScanStrings.verifiedAt,
            value: ScanStrings.verifiedAtValue(formatClock(verifiedAt)),
            dot: color,
          ),
        ],
      ),
    );
  }
}

/// 카드 안 정보 한 줄. 왼쪽에 이름, 오른쪽에 값.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.dot});

  final String label;
  final String value;

  /// 값 앞의 점. 없으면 안 그린다.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dotColor = dot;
    return Row(
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        if (dotColor != null) ...[
          Container(
            width: ScanMetrics.statusDotSize,
            height: ScanMetrics.statusDotSize,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 결과 화면의 버튼. 세 결과 모두 하나뿐이고 하는 일도 하나다 — 닫고 다음 QR.
///
/// 전에는 '다음 QR' 과 '확인' 두 개였는데 둘 다 같은 콜백을 불렀다. 같은 일을
/// 하는 버튼이 둘이면 운영자가 어느 쪽이 무엇인지 매번 고민한다.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: 20),
        label: const Text(ScanStrings.confirm),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
      ),
    );
  }
}
