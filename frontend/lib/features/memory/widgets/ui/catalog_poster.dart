import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';

/// 카탈로그 포스터의 이미지 출처.
///
/// 카탈로그는 서버에서 오지만(절대 주소) 목 구현과 위젯 테스트는 앱 에셋
/// 경로를 쓴다. 한 문자열이 둘 중 무엇인지는 여기서만 가린다 — 그리는 쪽마다
/// 판단하면 새 화면이 생길 때 한 곳만 빠뜨려도 조용히 안 뜬다.
///
/// 비어 있으면 null 이다. 포스터 없는 공연이 정상이라 그릴 것이 없는 것도
/// 정상이고, 부르는 쪽이 회색 자리를 그린다.
ImageProvider? catalogPosterImage(String poster) {
  if (poster.isEmpty) return null;
  if (poster.startsWith('assets/')) return AssetImage(poster);

  final url = ApiClient.imageUrl(poster);
  return url == null ? null : NetworkImage(url);
}

/// 카탈로그 포스터 한 장. 못 읽으면 회색 자리를 그린다.
class CatalogPoster extends StatelessWidget {
  const CatalogPoster(
    this.poster, {
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 0,
  });

  final String poster;
  final double width, height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = catalogPosterImage(poster);
    return SizedBox(
      width: width,
      height: height,
      child: image == null
          ? _empty
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _empty,
              ),
            ),
    );
  }

  Widget get _empty => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x14000000),
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}
