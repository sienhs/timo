import 'package:flutter/material.dart';

import 'poster_placeholder.dart';

/// 공연 포스터(사각). 이미지를 못 읽으면 플레이스홀더로 대체한다.
class PosterThumbnail extends StatelessWidget {
  const PosterThumbnail({
    super.key,
    required this.assetPath,
    this.width = 84,
    this.height = 112,
  });

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        // 원본이 표시 크기보다 훨씬 크므로 표시할 만큼만 디코딩한다.
        cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => PosterPlaceholder(
          width: width,
          height: height,
        ),
      ),
    );
  }
}
