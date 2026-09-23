import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';
import 'resale_card.dart';

/// 양도마켓 목록을 불러오는 동안 그 자리에 두는 빈 카드들. 껍데기는 실제
/// 카드와 같은 [ResaleCard] 를 쓴다. 포스터가 있는 목록과 글자만 있는 매물
/// 줄은 [withPoster] 로 갈린다.
class ResaleListSkeleton extends StatelessWidget {
  const ResaleListSkeleton({
    super.key,
    this.count = _defaultCount,
    this.withPoster = true,
  });

  /// 그릴 빈 카드 수.
  final int count;

  /// 왼쪽에 포스터 자리를 둘지.
  final bool withPoster;

  /// 폰 한 화면에 들어가는 만큼.
  static const _defaultCount = 5;

  /// 글자 줄 높이. 카드가 [TextStyle] 을 직접 들고 있어(디자인 토큰이 아직
  /// 없다) 거기 적힌 크기를 그대로 따른다.
  static const _titleLineHeight = 15.0;
  static const _metaLineHeight = 12.0;
  static const _lineGap = 6.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ResaleStrings.loading,
      child: ListView(
        // 뼈대를 굴려 볼 일은 없다.
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          ResaleMetrics.horizontalPadding,
          8,
          ResaleMetrics.horizontalPadding,
          8,
        ),
        children: [
          for (var i = 0; i < count; i++)
            ResaleCard(
              child: withPoster
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SizedBox(
                          width: ResaleMetrics.posterWidth,
                          height: ResaleMetrics.posterHeight,
                          child: SkeletonBox(
                            radius: ResaleMetrics.posterRadius,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: _TextLines()),
                      ],
                    )
                  : const _TextLines(),
            ),
        ],
      ),
    );
  }
}

/// 카드 오른쪽(또는 전부)에 들어가는 글자 줄들.
class _TextLines extends StatelessWidget {
  const _TextLines();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Line(height: ResaleListSkeleton._titleLineHeight, widthFactor: 0.65),
        SizedBox(height: ResaleListSkeleton._lineGap),
        _Line(height: ResaleListSkeleton._metaLineHeight, widthFactor: 0.9),
        SizedBox(height: ResaleListSkeleton._lineGap),
        _Line(height: ResaleListSkeleton._metaLineHeight, widthFactor: 0.4),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.height, required this.widthFactor});

  final double height;

  /// 가로 폭에서 차지하는 비율. 줄마다 길이가 달라야 글처럼 읽힌다.
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: SizedBox(
        height: height,
        child: const SkeletonBox(radius: ResaleMetrics.posterRadius / 2),
      ),
    );
  }
}
