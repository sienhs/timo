import 'package:flutter/material.dart';

import '../constants.dart';

/// 예매 안내 문단. 문단 사이 간격은 여기서 준다 — 문자열에 빈 줄을 넣으면
/// 간격을 바꿀 때 데이터를 고쳐야 한다.
class ShowNotice extends StatelessWidget {
  const ShowNotice({super.key, required this.paragraphs});

  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index++) ...[
          if (index > 0)
            const SizedBox(height: ShowDetailMetrics.noticeParagraphGap),
          Text(paragraphs[index], style: style),
        ],
      ],
    );
  }
}
