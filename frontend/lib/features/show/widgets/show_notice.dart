import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 공연 상세의 NOTICE 자리.
///
/// 주최사가 올린 안내 이미지가 있으면 **서버가 준 순서 그대로** 싣고, 없으면
/// 서비스 공통 규정([ShowDetailStrings.defaultNoticeLines])을 대신 적는다.
/// 이미지가 없다고 자리를 접으면 예매 마감·양도·환불처럼 예매 전에 알아야 할
/// 것이 어느 화면에도 나오지 않는다 — 그 규정들은 공연과 무관하게 항상 같다.
///
/// 이미지 주소는 [ApiClient.imageUrl] 을 거친다. 서버가 저장소 key 만 줄 수
/// 있어서다 (포스터·아티스트 사진과 같은 이유). 이미 완전한 주소면 그대로
/// 쓰인다. 거치지 않으면 key 로 오는 환경에서 안내만 조용히 실패한다 — 문구가
/// 뜨긴 하지만 원인을 화면에서는 알 수 없다.
class ShowNotice extends StatelessWidget {
  const ShowNotice({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const _DefaultNotice();
    }

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

/// 안내 이미지가 없는 공연에 적는 공통 규정.
class _DefaultNotice extends StatelessWidget {
  const _DefaultNotice();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      height: ShowDetailMetrics.noticeLineHeight,
    );

    const lines = ShowDetailStrings.defaultNoticeLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          if (index > 0)
            const SizedBox(height: ShowDetailMetrics.noticeLineGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: style),
              Expanded(child: Text(lines[index], style: style)),
            ],
          ),
        ],
      ],
    );
  }
}
