import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 공연 포스터 이미지. 부모가 준 크기를 꽉 채우고, 못 읽으면 회색 자리로
/// 대체한다.
///
/// 홈에 있던 위젯을 여기로 올렸다. 홈 카드 · 아티스트 아바타 · 배너에 이어
/// 공연 상세까지 같은 이유로 쓰게 되어, 원래 파일에 적어 둔 승격 조건('세
/// 번째 화면이 같은 이유로 포스터를 그리면')을 채웠다.
///
/// 결제 도메인의 `PosterThumbnail` 은 아직 합치지 않는다. 저쪽은 크기가
/// 고정된 썸네일이고 이쪽은 부모 박스를 채우는 형태여서, 하나로 묶으면
/// 크기 관련 파라미터가 양쪽 사정을 모두 받아야 한다.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.assetPath,
    this.borderRadius = 0,
    this.decodeWidth,
  });

  final String assetPath;
  final double borderRadius;

  /// 디코딩할 가로 픽셀 수의 기준이 되는 표시 폭. 샘플 포스터 원본이
  /// 표시 크기보다 훨씬 커서, 넘겨주면 메모리를 크게 아낀다.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final width = decodeWidth;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        cacheWidth: width == null
            ? null
            : (width * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppColors.surfaceMuted,
          child: Center(
            child: Icon(Icons.image_outlined, color: AppColors.textDisabled),
          ),
        ),
      ),
    );
  }
}
