import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../models/zone.dart';
import 'venue_map.dart';

/// '잔여좌석보기' 패널.
class RemainingSeatsPanel extends StatelessWidget {
  const RemainingSeatsPanel({super.key, required this.zones, this.onZoneTap});

  final void Function(Zone)? onZoneTap;

  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    return _ZoneInfoPanel(
      description:
          '구역을 선택하면 해당 구역의 좌석으로 이동합니다. '
          '좌석이 선점되어 있는 경우, 표기 된 잔여좌석과 선택할 수 있는 잔여좌석이 다를 수 있습니다.',
      rows: [
        for (final zone in zones)
          _ZoneInfoRow(
            zone: zone,
            trailing: zone.isSoldOut ? '매진' : '${zone.availableCount}석',
            onTap: onZoneTap == null ? null : () => onZoneTap!(zone),
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
    this.onTap,
  });

  final Zone zone;
  final String trailing;
  final bool emphasizeTrailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            // 전체 지도 및 상세 좌석과 같은 구역색을 사용한다.
            SizedBox(
              width: 10,
              height: 10,
              child: ColoredBox(color: zoneColor(zone.id)),
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
            if (onTap != null) const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
