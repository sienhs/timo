import 'package:flutter/material.dart';

import 'poster_image.dart';

/// 아티스트 프로필 사진. 서버가 준 주소를 원형 칸에 채우고, 주소가 없거나 못
/// 읽으면 라쿤 마스코트 얼굴로 대신한다. 홈·찜·공연 상세가 같은 규칙을 써야
/// 해서 한 위젯이 맡는다 — 폴백이 화면마다 다르면 같은 아티스트가 어디서는
/// 글자, 어디서는 그림으로 보인다.
class ArtistPhoto extends StatelessWidget {
  const ArtistPhoto({super.key, required this.url, required this.size});

  /// 사진이 없을 때 그리는 얼굴.
  static const fallbackAsset = 'assets/images/mascot_fallback_face.png';

  /// 서버 저장소 key 또는 주소. null 이면 바로 마스코트를 그린다.
  final String? url;

  /// 표시 폭. 원본이 표시 크기보다 훨씬 커서 디코딩 크기를 여기에 맞춘다.
  final double size;

  @override
  Widget build(BuildContext context) {
    return PosterImage.network(
      url: url,
      decodeWidth: size,
      fallback: PosterImage.asset(assetPath: fallbackAsset, decodeWidth: size),
    );
  }
}
