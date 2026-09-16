import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/ambient_motion.dart';
import '../motion/motion_tokens.dart';
import '../theme/memory_theme.dart';

/// 메모리 티켓 화면 전환: 페이드 + 완만한 확대·이동.
///
/// 같은 애니메이션이 중간 지점에서 배경(앰비언트)까지 한 번 밀어 올려서,
/// 나가는 화면·배경·들어오는 화면이 따로 노는 게 아니라 한 동작으로 읽힌다.
/// 들어온 화면의 [Reveal] 들이 그 뒤를 이어 차례로 나타난다.
Route<T> memoryRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 460),
  reverseTransitionDuration: Motion.base,
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) {
    final curve = CurvedAnimation(parent: animation, curve: Motion.emphasized);
    return _AmbientDrive(
      animation: animation,
      child: FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curve),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        ),
      ),
    );
  },
);

/// 어두운 무대 라우트. 소장품 뷰어와 실험실은 효과가 어두운 배경에 맞춰
/// 조정돼 있어 앱의 밝은 테마 대신 이쪽을 쓴다.
Route<T> stageRoute<T>(Widget page) =>
    memoryRoute<T>(Theme(data: timoDarkTheme(), child: page));

/// 라우트 애니메이션을 [AmbientMotion.energy] 에 묶는다. 전환 중간에서 가장
/// 높고 끝나면 평소 값으로 돌아온다. 앞 화면이 남긴 선택 포커스도 지운다.
class _AmbientDrive extends StatefulWidget {
  const _AmbientDrive({required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  State<_AmbientDrive> createState() => _AmbientDriveState();
}

class _AmbientDriveState extends State<_AmbientDrive> {
  @override
  void initState() {
    super.initState();
    widget.animation.addListener(drive);
    widget.animation.addStatusListener(settle);
    AmbientMotion.instance.clearFocus();
  }

  void drive() {
    final t = widget.animation.value;
    final surge = math.sin(t * math.pi);
    AmbientMotion.instance.setEnergy(
      AmbientMotion.restEnergy + (1 - AmbientMotion.restEnergy) * surge,
    );
  }

  void settle(AnimationStatus status) {
    if (!status.isAnimating) AmbientMotion.instance.relaxEnergy();
  }

  @override
  void dispose() {
    widget.animation.removeListener(drive);
    widget.animation.removeStatusListener(settle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
