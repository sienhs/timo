import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import 'poster_placeholder.dart';

/// 공연 포스터(사각). 주소가 없거나 이미지를 못 읽으면 플레이스홀더로 대체한다.
///
/// 주소는 [ApiClient.imageUrl] 을 거친다. 서버가 저장소 key 만 주기 때문에
/// (`poster/xxx.gif`) 그대로 쓰면 안드로이드에서 한 장도 안 뜬다.
class PosterThumbnail extends StatelessWidget {
  const PosterThumbnail({
    super.key,
    required this.url,
    this.width = 84,
    this.height = 112,
  });

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiClient.imageUrl(url);
    if (resolved == null) {
      return PosterPlaceholder(width: width, height: height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        resolved,
        width: width,
        height: height,
        fit: BoxFit.cover,
        // 원본이 표시 크기보다 훨씬 크므로 표시할 만큼만 디코딩한다.
        cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, _, _) =>
            PosterPlaceholder(width: width, height: height),
      ),
    );
  }
}
