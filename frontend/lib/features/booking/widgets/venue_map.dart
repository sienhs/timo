import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/zone.dart';
import '../state/booking_scope.dart';

/// 공연장 구역 배치도.
///
/// 시안의 배치도는 STAGE 아래에 FLOOR A(좌) · B(우), 그 밑에 C 가 오는
/// 고정 형태다. 주최사가 배치도를 직접 구성하는 기능은 이번 범위 밖이라
/// 좌표 데이터를 두지 않고 이 형태에 구역 3개를 꽂는다. 배치도 편집이
/// 들어오면 이 위젯이 좌표 기반으로 바뀌어야 한다.
///
/// 시안대로 매진 구역도 다른 구역과 같은 색으로 둔다. 매진 여부는 눌렀을 때
/// 화면이 안내한다.
class VenueMap extends StatelessWidget {
  const VenueMap({super.key, required this.onZoneTap});

  final void Function(Zone zone) onZoneTap;

  static const _flankHeight = 96.0;
  static const _bottomHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    final zones = BookingScope.of(context).zones;
    assert(zones.length == 3, '시안 배치도는 구역 3개 기준이다');
    final [left, right, bottom] = zones;

    return Container(
      padding: const EdgeInsets.all(14),
      color: AppColors.mapSurface,
      child: Column(
        // stretch 가 없으면 FLOOR C 처럼 Expanded 밖에 있는 구역이 글자 폭으로
        // 쪼그라든다(Column 기본 정렬이 center 라서).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StageBar(),
          Row(
            children: [
              Expanded(
                flex: 36,
                child: _ZoneBlock(
                  zone: left,
                  height: _flankHeight,
                  onTap: onZoneTap,
                ),
              ),
              // 무대 돌출부. STAGE 바와 이어져 시안의 T 자 형태를 만든다.
              const Expanded(
                flex: 28,
                child: SizedBox(
                  height: _flankHeight,
                  child: ColoredBox(color: AppColors.stageFill),
                ),
              ),
              Expanded(
                flex: 36,
                child: _ZoneBlock(
                  zone: right,
                  height: _flankHeight,
                  onTap: onZoneTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ZoneBlock(
            zone: bottom,
            height: _bottomHeight,
            onTap: onZoneTap,
          ),
        ],
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      alignment: Alignment.center,
      color: AppColors.stageFill,
      child: Text(
        'STAGE',
        // TextStyle 을 새로 만들지 않고 테마를 경유한다. 직접 만들면
        // 나중에 fontFamily 를 지정할 때 이 글자만 기본 폰트로 남는다.
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}

class _ZoneBlock extends StatelessWidget {
  const _ZoneBlock({
    required this.zone,
    required this.height,
    required this.onTap,
  });

  final Zone zone;
  final double height;
  final void Function(Zone zone) onTap;

  @override
  Widget build(BuildContext context) {
    // 매진 구역도 탭은 받는다. 아무 반응이 없으면 사용자는 앱이 멈춘 줄 안다.
    // 매진 안내는 화면(onTap)이 띄운다.
    return GestureDetector(
      onTap: () => onTap(zone),
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.zoneFill),
          child: Center(
            child: Text(
              zone.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
