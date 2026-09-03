import 'package:flutter/material.dart';

import '../constants.dart';
import 'poster_placeholder.dart';

/// 완료 화면 상단의 원형 포스터. 이미지를 못 읽으면 플레이스홀더로 대체한다.
class PosterAvatar extends StatelessWidget {
  const PosterAvatar({
    super.key,
    required this.assetPath,
    this.diameter = 132,
  });

  final String assetPath;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PaymentColors.avatarRing, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          // 원본이 표시 크기보다 훨씬 크므로 표시할 만큼만 디코딩한다.
          cacheWidth:
              (diameter * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: (_, _, _) => PosterPlaceholder(
            width: diameter,
            height: diameter,
          ),
        ),
      ),
    );
  }
}
