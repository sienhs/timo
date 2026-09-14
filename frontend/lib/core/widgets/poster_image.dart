import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../theme/app_colors.dart';

/// 공연 포스터 이미지. 부모가 준 크기를 꽉 채우고, 못 읽으면 회색 자리로
/// 대체한다.
///
/// 앱 에셋([PosterImage.asset])과 서버가 준 주소([PosterImage.network]) 두
/// 출처를 받는다. 홈 카드는 서버 응답의 URL 을, 배너·아티스트·상세는 아직
/// 에셋을 그린다. 출처가 무엇이든 그리는 방식(채우기·모서리·대체 자리)은
/// 같아야 해서 한 위젯이 맡는다.
///
/// 홈에 있던 위젯을 여기로 올렸다. 홈 카드 · 아티스트 아바타 · 배너에 이어
/// 공연 상세까지 같은 이유로 쓰게 되어, 원래 파일에 적어 둔 승격 조건('세
/// 번째 화면이 같은 이유로 포스터를 그리면')을 채웠다.
///
/// 결제 도메인의 `PosterThumbnail` 은 아직 합치지 않는다. 저쪽은 크기가
/// 고정된 썸네일이고 이쪽은 부모 박스를 채우는 형태여서, 하나로 묶으면
/// 크기 관련 파라미터가 양쪽 사정을 모두 받아야 한다.
class PosterImage extends StatelessWidget {
  /// 앱에 들어 있는 이미지.
  ///
  /// 생성자가 const 가 아닌 이유: 인자로 받은 경로로 [ImageProvider] 를 만드는
  /// 일은 컴파일 시점에 할 수 없다. 어차피 경로는 늘 데이터에서 오므로 호출부가
  /// const 를 잃는 일도 없다.
  PosterImage.asset({
    super.key,
    required String assetPath,
    this.borderRadius = 0,
    this.decodeWidth,
  }) : _image = AssetImage(assetPath);

  /// 서버가 준 주소의 이미지. 주소가 없으면(포스터 없는 공연) 바로 회색
  /// 자리를 그린다.
  ///
  /// 주소는 [ApiClient.imageUrl] 을 거친다. 서버가 저장소 key 만 주기 때문에
  /// (`poster/xxx.gif`) 그대로 쓰면 안드로이드에서 한 장도 안 뜬다. 호출부마다
  /// 서버 주소를 붙이게 하면 빠뜨린 화면만 조용히 깨지므로 여기서 한 번에 한다.
  PosterImage.network({
    super.key,
    required String? url,
    this.borderRadius = 0,
    this.decodeWidth,
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
