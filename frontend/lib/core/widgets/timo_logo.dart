import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TIMO 로고 이미지.
///
/// 인증 화면(로그인·가입 단계·가입 완료)에 있던 위젯을 홈 상단 바도 같은
/// 이유로 쓰게 되어 여기로 올렸다. 로고는 어느 화면에서든 같은 파일·같은
/// 대체 글자로 그려져야 한다.
///
/// 원본 파일이 2820×1472 로 커서 그리는 높이에 맞춰 디코딩 크기를 줄인다
/// (cacheHeight). 파일이 아직 없거나 깨졌으면 브랜드색 'TIMO' 글자로 대신
/// 그려서 화면이 비거나 앱이 죽지 않게 한다.
class TimoLogo extends StatelessWidget {
  const TimoLogo({super.key, this.height = defaultHeight});

  /// 헤더에 놓을 때의 높이. 로그인 헤더와 홈 상단 바가 같은 값을 쓴다.
  static const defaultHeight = 24.0;

  static const asset = 'assets/images/timo_logo.png';

  final double height;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      asset,
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
