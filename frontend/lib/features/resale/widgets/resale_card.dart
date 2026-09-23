import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 양도마켓 목록 카드 한 장의 껍데기. 흰 바탕, 테두리, 둥근 모서리. 공연 카드
/// · 매물 줄 · 등록할 티켓 카드가 같은 상자에 들어간다. [selected] 는 등록
/// 화면에서 티켓을 고른 상태로, 테두리만 브랜드색으로 두껍게 그린다 — 굵기가
/// 함께 변해 색을 구별 못 하는 눈에도 드러난다.
class ResaleCard extends StatelessWidget {
  const ResaleCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
  });

  final Widget child;

  /// 누를 수 있는 카드인지. null 이면 눌리지 않는다(내 매물 등).
  final VoidCallback? onTap;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ResaleMetrics.cardRadius);

    return Container(
      margin: const EdgeInsets.only(bottom: ResaleMetrics.cardGap),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? ResaleMetrics.selectedBorderWidth : 1,
        ),
        borderRadius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(ResaleMetrics.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 카드 안의 정보 한 줄. 아이콘 + 회색 글자.
class ResaleInfoLine extends StatelessWidget {
  const ResaleInfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: ResaleMetrics.infoIconSize,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 카드에 붙는 작은 알림표. 상태 배지와 달리 색을 밖에서 받는다.
class ResaleChip extends StatelessWidget {
  const ResaleChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
