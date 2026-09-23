import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../constants.dart';
import 'poster_placeholder.dart';

/// 완료 화면 상단의 원형 포스터. 주소가 없거나 이미지를 못 읽으면
/// 플레이스홀더로 대체한다.
class PosterAvatar extends StatelessWidget {
  const PosterAvatar({super.key, required this.url, this.diameter = 132});

  final String? url;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiClient.imageUrl(url);

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: PaymentColors.avatarRing, width: 2),
      ),
      child: ClipOval(
        child: resolved == null
            ? PosterPlaceholder(width: diameter, height: diameter)
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                // 원본이 표시 크기보다 훨씬 크므로 표시할 만큼만 디코딩한다.
                cacheWidth: (diameter * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                // 그림이 내려오는 동안은 회색 자리를 둔다 — 완료 화면이
                // 빈 동그라미로 열렸다가 채워지지 않게.
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                    wasSynchronouslyLoaded || frame != null
                    ? child
                    : PosterPlaceholder.loading(
                        width: diameter,
                        height: diameter,
                      ),
                errorBuilder: (_, _, _) =>
                    PosterPlaceholder(width: diameter, height: diameter),
              ),
      ),
    );
  }
}
