import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 공연 상세의 NOTICE 자리. 주최사가 올린 안내 이미지가 있으면 서버가 준 순서 그대로
/// 싣고, 없으면 서비스 공통 규정([ShowDetailStrings.defaultNoticeLines])을 대신 적는다.
/// 이미지 주소는 서버가 저장소 key 만 줄 수 있어 [ApiClient.imageUrl] 을 거친다.
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
