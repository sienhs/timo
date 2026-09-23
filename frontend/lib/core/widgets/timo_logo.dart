import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TIMO 로고 이미지. 원본이 2820×1472 로 커서 그리는 높이에 맞춰 디코딩 크기를
/// 줄이고, 파일이 없거나 깨졌으면 브랜드색 'TIMO' 글자로 대신 그린다.
class TimoLogo extends StatelessWidget {
  const TimoLogo({super.key, this.height = defaultHeight});

  /// 헤더에 놓을 때의 높이. 로그인 헤더와 홈 상단 바가 같은 값을 쓴다.
  static const defaultHeight = 24.0;

  static const asset = 'assets/images/timo_logo.png';

  final double height;

  /// [height] 로 그릴 때 쓰는 이미지. 이미지 캐시가 제공자(파일 + 디코딩 크기)를
  /// 키로 삼으므로 [build] 와 [precache] 가 반드시 같은 것을 써야 한다.
  static ImageProvider _provider(BuildContext context, double height) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ResizeImage(const AssetImage(asset), height: (height * dpr).round());
  }

  /// 로고를 미리 디코딩해 캐시에 넣는다. 로고가 뒤늦게 나타나는 화면이 먼저
  /// 불러 빈 화면이 보이지 않게 한다. 실패는 조용히 넘긴다(대체 글자로 그린다).
  static Future<void> precache(
    BuildContext context, {
    double height = defaultHeight,
  }) => precacheImage(_provider(context, height), context, onError: (_, _) {});

  @override
  Widget build(BuildContext context) {
    return Image(
      image: _provider(context, height),
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
          color: AppColors.primary,
        ),
      ),
    );
  }
}
