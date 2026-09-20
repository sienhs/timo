import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';

/// 공연 포스터. 부모가 준 크기를 꽉 채우고, 못 읽으면 회색 자리로 대체한다.
///
/// 팬 앱 `core/widgets/poster_image.dart` 에서 게이트가 쓰는 만큼만 가져왔다
/// (게이트는 서버가 준 주소만 그리므로 에셋 생성자는 없다).
///
/// 주소는 [ApiClient.imageUrl] 을 거친다. 서버가 저장소 key 만 주기 때문에
/// 그대로 쓰면 한 장도 안 뜬다.
class PosterImage extends StatelessWidget {
  /// 생성자가 const 가 아닌 이유: 인자로 받은 주소로 [ImageProvider] 를 만드는
  /// 일은 컴파일 시점에 할 수 없다. 주소는 늘 서버 응답에서 오므로 호출부가
  /// const 를 잃는 일도 없다.
  PosterImage.network({
    super.key,
    required String? url,
    this.borderRadius = 0,
    this.decodeWidth,
  }) : _image = _networkImageOrNull(url);

  static ImageProvider? _networkImageOrNull(String? url) {
    final resolved = ApiClient.imageUrl(url);
    return resolved == null ? null : NetworkImage(resolved);
  }

  final ImageProvider? _image;
  final double borderRadius;

  /// 디코딩할 가로 픽셀 수의 기준이 되는 표시 폭. 포스터 원본이 표시 크기보다
  /// 훨씬 커서, 넘겨주면 메모리를 크게 아낀다.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final width = decodeWidth;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: image == null
          ? const _Placeholder()
          : Image(
              image: ResizeImage.resizeIfNeeded(
                width == null
                    ? null
                    : (width * MediaQuery.devicePixelRatioOf(context)).round(),
                null,
                image,
              ),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _Placeholder(),
            ),
    );
  }
}

/// 포스터가 없거나 못 읽었을 때의 회색 자리. 무엇이 있어야 할 자리인지
/// 알 수 있게 옅은 아이콘을 하나 둔다.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textDisabled,
          size: 20,
        ),
      ),
    );
  }
}
