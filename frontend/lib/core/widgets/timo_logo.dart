import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TIMO 로고 이미지.
///
/// 인증 화면(로그인·가입 단계·가입 완료)에 있던 위젯을 홈 상단 바도 같은
/// 이유로 쓰게 되어 여기로 올렸다. 로고는 어느 화면에서든 같은 파일·같은
/// 대체 글자로 그려져야 한다.
///
/// 원본 파일이 2820×1472 로 커서 그리는 높이에 맞춰 디코딩 크기를 줄인다.
/// 파일이 아직 없거나 깨졌으면 브랜드색 'TIMO' 글자로 대신 그려서 화면이
/// 비거나 앱이 죽지 않게 한다.
class TimoLogo extends StatelessWidget {
  const TimoLogo({super.key, this.height = defaultHeight});

  /// 헤더에 놓을 때의 높이. 로그인 헤더와 홈 상단 바가 같은 값을 쓴다.
  static const defaultHeight = 24.0;

  static const asset = 'assets/images/timo_logo.png';

  final double height;

  /// [height] 로 그릴 때 쓰는 이미지. 화면 배율을 곱한 픽셀 높이로 디코딩한다.
  ///
  /// [build] 와 [precache] 가 **반드시 같은 것**을 써야 한다. 이미지 캐시는
  /// 제공자(파일 + 디코딩 크기)를 키로 삼아서, 하나라도 다르면 미리 읽어 둔
  /// 것이 쓰이지 않고 다시 디코딩한다.
  static ImageProvider _provider(BuildContext context, double height) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ResizeImage(const AssetImage(asset), height: (height * dpr).round());
  }

  /// 로고를 미리 디코딩해 캐시에 넣는다.
  ///
  /// 로고가 뒤늦게 나타나는 화면(로딩 화면의 마지막 장면)이 먼저 부른다. 원본이
  /// 커서 나타날 자리에서 읽으면 디코딩하는 동안 빈 화면이 잠깐 보인다. 실패는
  /// 조용히 넘긴다 — 그리는 쪽이 대체 글자로 처리한다.
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
