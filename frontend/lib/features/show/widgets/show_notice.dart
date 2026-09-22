import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../constants.dart';

/// 서버가 준 순서대로 공연별 안내 이미지를 표시한다.
///
/// 주소는 [ApiClient.imageUrl] 을 거친다. 서버가 저장소 key 만 줄 수 있어서다
/// (포스터·아티스트 사진과 같은 이유). 이미 완전한 주소면 그대로 쓰인다.
/// 거치지 않으면 key 로 오는 환경에서 안내만 조용히 실패한다 — 문구가 뜨긴
/// 하지만 원인을 화면에서는 알 수 없다.
class ShowNotice extends StatelessWidget {
  const ShowNotice({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < imageUrls.length; index++) ...[
          if (index > 0)
            const SizedBox(height: ShowDetailMetrics.noticeImageGap),
          Image.network(
            ApiClient.imageUrl(imageUrls[index]) ?? imageUrls[index],
            width: double.infinity,
            fit: BoxFit.fitWidth,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: Text(ShowDetailStrings.noticeImageLoading),
                  ),
            errorBuilder: (context, error, stackTrace) =>
                const Center(child: Text(ShowDetailStrings.noticeImageError)),
          ),
        ],
      ],
    );
  }
}
