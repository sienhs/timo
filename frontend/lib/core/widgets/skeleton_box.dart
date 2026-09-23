import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 불러오는 동안 내용 자리에 두는 회색 상자.
///
/// 홈 · 티켓 · 공연 · 양도마켓의 스켈레톤이 모두 이 한 조각을 쌓아 만든다.
/// 원래 홈에 있었지만 티켓이 도메인을 가로질러 가져다 쓰기 시작해 여기로
/// 올렸다 — 같은 회색을 화면마다 다시 정의하면 색이 갈라진다.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
