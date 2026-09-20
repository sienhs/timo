import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TIMO 마스코트 그림. 팬 앱 `core/widgets/timo_mascot.dart` 에서 게이트가
/// 쓰는 표정만 가져왔다.
///
/// 지금은 우는 표정 하나뿐이다 — 게이트에서 마스코트를 보게 되는 자리는 공연
/// 목록이 비었을 때뿐이라, 다른 표정은 쓰는 화면이 생길 때 늘린다. 안 쓰는
/// 그림을 미리 넣으면 APK 만 무거워진다.
///
/// 원본이 표시 크기보다 훨씬 커서 그리는 크기에 맞춰 디코딩 크기를 줄인다.
/// 파일이 없거나 깨졌으면 [fallbackIcon] 으로 대신 그려 화면이 비지 않게 한다.
class TimoMascot extends StatelessWidget {
  /// 우는 표정. 빈 목록이나 허탕 친 자리에 쓴다.
  const TimoMascot.sad({super.key, this.size = defaultSize})
    : _asset = sadAsset,
      _semanticLabel = '우는 티모';

  static const defaultSize = 140.0;

  static const sadAsset = 'assets/images/mascot_crying.png';

  /// 그림을 못 읽었을 때 같은 자리에 그리는 아이콘.
  static const fallbackIcon = Icons.confirmation_number_outlined;

  final String _asset;
  final String _semanticLabel;

  /// 한 변의 길이. 그림이 정사각형이라 가로·세로가 같다.
  final double size;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        _asset,
        fit: BoxFit.contain,
        cacheWidth: (size * dpr).round(),
        semanticLabel: _semanticLabel,
        errorBuilder: (context, error, stackTrace) =>
            Icon(fallbackIcon, size: size * 0.6, color: AppColors.textDisabled),
      ),
    );
  }
}
