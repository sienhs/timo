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
      note: '구역을 선택하면 그 구역의 좌석으로 이동합니다.',
      // 표기된 수와 실제로 고를 수 있는 수가 다른 이유는 알아야 하지만, 목록
      // 위에 늘 두 줄로 깔려 있으면 정작 봐야 할 구역·좌석 수를 밀어낸다.
      // 그래서 물음표를 눌렀을 때만 편다(사용자 결정).
      hint: '선점 중인 좌석이 있어 실제로 고를 수 있는 자리는 더 적을 수 있어요.',
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

class _ZoneInfoPanel extends StatefulWidget {
  const _ZoneInfoPanel({required this.rows, this.note, this.hint});

  final List<Widget> rows;

  /// 목록 위에 늘 보이는 안내 한 줄.
  final String? note;

  /// 물음표를 눌러야 펴지는 덧붙임. 없으면 물음표도 두지 않는다.
  final String? hint;

  @override
  State<_ZoneInfoPanel> createState() => _ZoneInfoPanelState();
}

class _ZoneInfoPanelState extends State<_ZoneInfoPanel> {
  bool _hintOpen = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final hint = widget.hint;
    final rows = widget.rows;

    return ColoredBox(
      color: AppColors.mapSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note != null) ...[
              _PanelNote(
                note,
                trailing: hint == null
                    ? null
                    : _HintButton(
                        open: _hintOpen,
                        onTap: () => setState(() => _hintOpen = !_hintOpen),
                      ),
              ),
              if (hint != null && _hintOpen) _PanelNote(hint),
              const SizedBox(height: 10),
            ],
            // 행 사이를 선으로 가른다. 구역명과 숫자가 양 끝에 떨어져 있어
            // 선이 없으면 어느 숫자가 어느 구역 것인지 눈으로 잇기 어렵다.
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.border),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// 안내 문구 옆의 물음표. 눌러야 덧붙임이 펴진다.
class _HintButton extends StatelessWidget {
  const _HintButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? '잔여좌석 안내 접기' : '잔여좌석 안내 보기',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 글자에 붙은 아이콘이라 터치 타겟이 좁다. 여백으로 넓힌다.
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(
            open ? Icons.help : Icons.help_outline,
            size: 15,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 가운뎃점을 붙인 안내 한 줄.
class _PanelNote extends StatelessWidget {
  const _PanelNote(this.text, {this.trailing});

  final String text;

  /// 문장 끝에 따라붙는 것(물음표 등).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      // 두 줄로 넘어가는 문장이라 줄 간격을 벌려야 읽힌다.
      height: 1.5,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('·', style: style),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  if (trailing case final trailing?)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: trailing,
                    ),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// 오른쪽 숫자 칸의 폭. '186,000원' 이 한 줄에 들어가는 크기다.
const _trailingWidth = 84.0;

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
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // 전체 지도 및 상세 좌석과 같은 구역색을 사용한다.
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: zoneColor(zone.id),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                zone.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  // 이름이 흐리면 정작 무엇을 고르는지가 안 읽힌다. 강약은
                  // 오른쪽 숫자에서 준다.
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 숫자를 고정 폭에 오른쪽 맞춤으로 둔다. 이름 길이에 따라 숫자가
            // 들쭉날쭉하면 구역끼리 견줄 수가 없다.
            SizedBox(
              width: _trailingWidth,
              child: Text(
                trailing,
                textAlign: TextAlign.right,
                maxLines: 1,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: emphasizeTrailing
                      ? AppColors.accent
                      : AppColors.textPrimary,
                ),
              ),
            ),
            // 화살표가 없는 패널(좌석가격보기)도 같은 폭을 비워 둔다. 두 패널을
            // 오갈 때 숫자가 좌우로 튀지 않게 하려는 것이다.
            SizedBox(
              width: 20,
              child: onTap == null
                  ? null
                  : const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
