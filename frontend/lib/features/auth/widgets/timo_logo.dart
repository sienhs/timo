import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// TIMO 로고 이미지.
///
/// 원본 파일이 2820×1472 로 커서 그리는 높이에 맞춰 디코딩 크기를 줄인다
/// (cacheHeight). 파일이 아직 없거나 깨졌으면 브랜드색 'TIMO' 글자로 대신
/// 그려서 화면이 비거나 앱이 죽지 않게 한다.
class TimoLogo extends StatelessWidget {
  const TimoLogo({super.key, this.height = AuthMetrics.headerLogoHeight});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      AuthAssets.logo,
      height: height,
      fit: BoxFit.contain,
      cacheHeight: (height * dpr).round(),
      semanticLabel: 'TIMO',
      errorBuilder: (context, error, stackTrace) =>
          _FallbackText(height: height),
    );
  }
}

/// 이미지가 없을 때의 글자 로고. 이미지와 같은 높이를 차지한다.
class _FallbackText extends StatelessWidget {
  const _FallbackText({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Text(
        'TIMO',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontSize: height * 0.9,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
