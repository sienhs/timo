import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TIMO 로고 이미지. 팬 앱 `core/widgets/timo_logo.dart` 와 같은 파일·같은
/// 대체 글자를 쓴다 — 두 앱의 로고가 서로 달라 보이면 안 된다.
///
/// 원본 파일이 2820×1472 로 커서 그리는 높이에 맞춰 디코딩 크기를 줄인다.
/// 파일이 없거나 깨졌으면 브랜드색 'TIMO' 글자로 대신 그려서 화면이 비거나
/// 앱이 죽지 않게 한다.
class TimoLogo extends StatelessWidget {
  const TimoLogo({super.key, this.height = defaultHeight});

  /// 로그인 헤더에 놓을 때의 높이.
  static const defaultHeight = 28.0;

  static const asset = 'assets/images/timo_logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return Image(
      image: ResizeImage(
        const AssetImage(asset),
        height: (height * dpr).round(),
      ),
      height: height,
      fit: BoxFit.contain,
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
          color: AppColors.primaryPressed,
        ),
      ),
    );
  }
}
