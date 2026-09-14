import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/zone.dart';

/// '잔여좌석보기' 패널.
class RemainingSeatsPanel extends StatelessWidget {
  const RemainingSeatsPanel({super.key, required this.zones});

  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    return _ZoneInfoPanel(
      description:
          '좌석명을 선택하시면 각 구역 별 잔여좌석을 확인할 수 있습니다. '
          '좌석이 선점되어 있는 경우, 표기 된 잔여좌석과 선택할 수 있는 잔여좌석이 다를 수 있습니다.',
      rows: [
        for (final zone in zones)
          _ZoneInfoRow(
            zone: zone,
            trailing: '${zone.availableCount}석',
            emphasizeTrailing: zone.isSoldOut,
          ),
      ],
    );
  }
}

/// '좌석가격보기' 패널.
///
/// 요구사항상 좌석 등급이 없어 구역마다 같은 값이 찍히는 게 정상이지만, 서버
/// 데이터는 층마다 가격이 갈린다. 어느 쪽이든 서버가 준 값을 그대로 보여준다.
class ZonePricePanel extends StatelessWidget {
  const ZonePricePanel({super.key, required this.zones});

  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    return _ZoneInfoPanel(
      rows: [
        for (final zone in zones)
          _ZoneInfoRow(
            zone: zone,
            trailing: formatWon(zone.price),
            emphasizeTrailing: true,
          ),
      ],
    );
  }
}

class _ZoneInfoPanel extends StatelessWidget {
  const _ZoneInfoPanel({required this.rows, this.description});

  final List<Widget> rows;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.mapSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description case final text?) ...[
              Text(text, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 18),
            ],
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _ZoneInfoRow extends StatelessWidget {
  const _ZoneInfoRow({
    required this.zone,
    required this.trailing,
    required this.emphasizeTrailing,
  });

  final Zone zone;
  final String trailing;
  final bool emphasizeTrailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          // 시안의 스와치는 배치도 구역색(베이지)이 아니라 회색이다.
          const SizedBox(
            width: 10,
            height: 10,
            child: ColoredBox(color: AppColors.swatch),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zone.name,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Text(
            trailing,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: emphasizeTrailing
                  ? AppColors.accent
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
