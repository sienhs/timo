import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';

/// 공연 포스터 이미지. 부모가 준 크기를 꽉 채우고, 못 읽으면 회색 자리로
/// 대체한다. 앱 에셋([PosterImage.asset])과 서버 주소([PosterImage.network])
/// 어느 출처든 채우기·모서리·대체 자리가 같아야 해서 한 위젯이 맡는다.
class PosterImage extends StatelessWidget {
  /// 앱에 들어 있는 이미지. 인자로 받은 경로로 [ImageProvider] 를 만들어야 해서
  /// 생성자가 const 가 아니다.
  PosterImage.asset({
    super.key,
    required String assetPath,
    this.borderRadius = 0,
    this.decodeWidth,
    this.fit = BoxFit.cover,
    this.fallback,
  }) : _image = AssetImage(assetPath);

  /// 서버가 준 주소의 이미지. 주소가 없으면(포스터 없는 공연) 바로 회색 자리를
  /// 그린다. 서버가 저장소 key 만 주므로 [ApiClient.imageUrl] 로 서버 주소를
  /// 여기서 한 번에 붙인다(호출부마다 붙이면 빠뜨린 화면만 조용히 깨진다).
  PosterImage.network({
    super.key,
    required String? url,
    this.borderRadius = 0,
    this.decodeWidth,
    this.fit = BoxFit.cover,
    this.fallback,
  }) : _image = _networkImageOrNull(url);

  /// 서버 주소를 붙여 [NetworkImage] 를 만든다. 붙일 주소가 없으면 null 이라
  /// 회색 자리가 그려진다.
  static ImageProvider? _networkImageOrNull(String? url) {
    final resolved = ApiClient.imageUrl(url);
    return resolved == null ? null : NetworkImage(resolved);
  }

  final ImageProvider? _image;
  final double borderRadius;

  /// 디코딩할 가로 픽셀 수의 기준이 되는 표시 폭. 포스터 원본이 표시
  /// 크기보다 훨씬 커서, 넘겨주면 메모리를 크게 아낀다.
  final double? decodeWidth;

  /// 받은 칸을 어떻게 채울지. 기본은 꽉 채우는 [BoxFit.cover] 다 — 카드·아바타는
  /// 칸에 빈 곳이 남으면 안 된다. [PosterStage] 처럼 포스터 비율을 그대로
  /// 두고 남는 자리를 따로 메우는 자리에서만 [BoxFit.contain] 을 넘긴다.
  final BoxFit fit;

  /// 그림이 없거나 못 읽었을 때 회색 자리 대신 그릴 위젯. 아티스트 사진처럼
  /// '없음' 을 사진 아이콘이 아닌 다른 얼굴로 보여야 하는 자리가 넘긴다.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final width = decodeWidth;
    final Widget missing = fallback ?? const _Placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image == null
          ? missing
          : Image(
              image: ResizeImage.resizeIfNeeded(
                width == null
                    ? null
                    : (width * MediaQuery.devicePixelRatioOf(context)).round(),
                null,
                image,
              ),
              fit: fit,
              // 그림이 내려오는 동안은 회색 자리를 둔다. 없으면 스켈레톤이 걷힌
              // 자리가 빈 칸으로 남았다가 그림이 튀어 들어온다.
              frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                  wasSynchronouslyLoaded || frame != null
                  ? child
                  : const _LoadingBox(),
              errorBuilder: (_, _, _) => missing,
            ),
    );
  }
}

/// 그림을 기다리는 동안의 자리. 못 읽었을 때의 [_Placeholder] 와 달리
/// 아이콘을 두지 않는다 — 오는 중인 그림이 '없는 그림' 으로 보이면 안 된다.
class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: SizedBox.expand(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(Icons.image_outlined, color: AppColors.textDisabled),
      ),
    );
  }
}
