import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TIMO 마스코트 그림. 표정별로 이름 있는 생성자를 두어 호출부가 파일 경로를
/// 모른다. 원본이 커서 그리는 크기에 맞춰 디코딩하고, 못 읽으면 [fallbackIcon]
/// 으로 대신 그린다.
class TimoMascot extends StatelessWidget {
  /// 엄지를 든 축하 표정. 가입 완료처럼 잘 끝난 자리에 쓴다.
  const TimoMascot.cheer({super.key, this.size = defaultSize})
    : _asset = cheerAsset,
      _semanticLabel = '축하하는 티모';

  /// 우는 표정. 빈 목록이나 실패처럼 허탕 친 자리에 쓴다.
  const TimoMascot.sad({super.key, this.size = defaultSize})
    : _asset = sadAsset,
      _semanticLabel = '우는 티모';

  static const defaultSize = 160.0;

  static const cheerAsset = 'assets/images/mascot_thumbs_up.png';
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
            Icon(fallbackIcon, size: size * 0.6, color: AppColors.primary),
      ),
    );
  }
}
