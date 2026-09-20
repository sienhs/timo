import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 불러오는 동안 내용 자리를 채워 두는 회색 상자.
///
/// 스피너 하나를 가운데 두는 대신 올 내용과 같은 크기의 상자를 깔면, 데이터가
/// 도착하는 순간 줄이 밀리지 않는다. 게이트에서는 공연 목록이 이걸 쓴다.
///
/// 은은하게 밝아졌다 어두워진다. 기기의 '동작 줄이기' 설정이 켜져 있으면
/// 움직이지 않고 회색으로만 둔다.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.radius = 8});

  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            AppColors.skeleton,
            AppColors.surfaceMuted,
            _pulse.value,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
