import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/zone.dart';

/// 공연장 구역 배치도.
///
/// 배치도는 STAGE 아래에 좌(A) · 우(B), 그 밑에 가로로 긴 구역(C), 맨 아래에
/// 같은 크기의 줄을 좌우로 나눈 2층 구역(D · E) 순이다. 주최사가 배치도를 직접
/// 구성하는 기능은 이번 범위 밖이라 좌표 데이터를 두지 않고 이 형태에 구역을
/// **순서대로** 꽂는다. 배치도 편집이 들어오면 이 위젯이 좌표 기반으로 바뀌어야
/// 한다.
///
/// 구역 수가 셋을 넘으면 넷째부터는 맨 아랫줄에 가로로 나눠 넣는다. 서버가 주는
/// 구역 수가 늘어도 그림이 깨지지 않게 하려는 것이다.
///
/// 시안대로 매진 구역도 다른 구역과 같은 색으로 둔다. 매진 여부는 눌렀을 때
/// 화면이 안내한다.
class VenueMap extends StatelessWidget {
  const VenueMap({super.key, required this.zones, required this.onZoneTap});

  /// 서버에서 받은 구역들. 순서가 곧 배치도의 자리다.
  final List<Zone> zones;

  final void Function(Zone zone) onZoneTap;

  static const _flankHeight = 96.0;

  /// 가로로 긴 구역 한 줄의 높이. C 와 그 아래 2층 줄이 같은 크기다.
  static const _bottomHeight = 58.0;

  /// 구역 사이 간격. 붙여 두면 어디까지가 한 구역인지 눈으로 갈리지 않는다.
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    assert(zones.length >= 3, '시안 배치도는 1층 구역 셋을 전제로 한다');
    final balcony = zones.skip(3).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      color: AppColors.mapSurface,
      child: Column(
        // stretch 가 없으면 FLOOR C 처럼 Expanded 밖에 있는 구역이 글자 폭으로
        // 쪼그라든다(Column 기본 정렬이 center 라서).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StageBar(),
          SizedBox(
            height: _flankHeight,
            child: Row(
              // 무대 돌출부는 글자가 없어 제 높이가 없다. stretch 가 없으면
              // Row 기본 정렬(center)에 눌려 높이 0 이 되고 T 자가 사라진다.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 36,
                  child: Padding(
                    // 무대와 띄운다. 붙여 두면 분홍 구역이 무대의 일부처럼 읽힌다.
                    padding: const EdgeInsets.only(top: _gap, right: _gap),
                    child: _ZoneBlock(zone: zones[0], onTap: onZoneTap),
                  ),
                ),
                // 무대 돌출부. STAGE 바와 이어져 시안의 T 자 형태를 만든다.
                // 여기에만 위쪽 여백을 주지 않는 이유가 그것이다.
                const Expanded(
                  flex: 28,
                  child: ColoredBox(color: AppColors.stageFill),
                ),
                Expanded(
                  flex: 36,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _gap, left: _gap),
                    child: _ZoneBlock(zone: zones[1], onTap: onZoneTap),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _gap),
          SizedBox(
            height: _bottomHeight,
            child: _ZoneBlock(zone: zones[2], onTap: onZoneTap),
          ),
          // 2층 줄. C 와 같은 크기의 줄을 구역 수만큼 나눠 쓴다.
          if (balcony.isNotEmpty) ...[
            const SizedBox(height: _gap),
            SizedBox(
              height: _bottomHeight,
              child: Row(
                children: [
                  for (var i = 0; i < balcony.length; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: _ZoneBlock(zone: balcony[i], onTap: onZoneTap),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
  const _ZoneBlock({required this.zone, required this.onTap});

  final Zone zone;
  final void Function(Zone zone) onTap;

  @override
  Widget build(BuildContext context) {
    final block = ColoredBox(
      color: AppColors.zoneFill,
      child: Center(
        child: Text(
          zone.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );

    // 매진 구역도 탭은 받는다. 아무 반응이 없으면 사용자는 앱이 멈춘 줄 안다.
    // 매진 안내는 화면(onTap)이 띄운다.
    return GestureDetector(onTap: () => onTap(zone), child: block);
  }
}
