import 'package:flutter/material.dart';

import '../../../core/widgets/skeleton_box.dart';
import '../constants.dart';

/// 공연을 불러오는 동안 상세 화면 자리에 두는 뼈대. 포스터 칸 · 제목 묶음 · 섹션 두 개를
/// 실제 화면과 같은 비율과 간격으로 세워([ShowDetailMetrics]) 포스터 자리가 그대로 이어진다.
/// 하단 바 자리는 비우지 않는다. 바 모양이 공연 상태에 따라 갈려 받기 전에는 알 수 없다.
class ShowDetailSkeleton extends StatelessWidget {
  const ShowDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleHeight = textTheme.titleLarge?.fontSize ?? 22;
    final lineHeight = textTheme.bodyMedium?.fontSize ?? 14;

    return Semantics(
      label: ShowDetailStrings.loading,
      child: ListView(
        // 뼈대를 굴려 볼 일은 없다. 스크롤은 잠그되 ListView 로 두어 짧은
        // 기기에서 넘칠 때 화면이 깨지지 않게 한다.
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: ShowDetailMetrics.contentBottomGap,
        ),
        children: [
          const AspectRatio(
            aspectRatio: ShowDetailMetrics.posterAspectRatio,
            child: SkeletonBox(radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ShowDetailMetrics.horizontalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: ShowDetailMetrics.summaryTopGap),
                _Line(height: titleHeight, widthFactor: 0.7),
                const SizedBox(height: ShowDetailMetrics.summaryLineGap),
                _Line(height: lineHeight, widthFactor: 0.45),
                const SizedBox(height: ShowDetailMetrics.summaryLineGap / 2),
                _Line(height: lineHeight, widthFactor: 0.55),
                const SizedBox(height: ShowDetailMetrics.sectionGap),
                _Section(titleHeight: lineHeight, height: _priceCardHeight),
                const SizedBox(height: ShowDetailMetrics.sectionGap),
                _Section(titleHeight: lineHeight, height: _artistRowHeight),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 구역별 가격 카드의 대략적인 높이. 구역 수만큼 늘어나는 카드라 정확히
  /// 맞출 수는 없고, 두세 구역일 때와 비슷한 높이로 잡는다.
  static const _priceCardHeight = 92.0;

  /// 아티스트 줄 높이. 동그란 사진과 이름 한 줄이 들어간다.
  static const _artistRowHeight =
      ShowDetailMetrics.artistAvatarSize + ShowDetailMetrics.artistNameGap + 16;
}

/// 섹션 하나: 제목 한 줄과 그 아래 내용 상자.
class _Section extends StatelessWidget {
  const _Section({required this.titleHeight, required this.height});

  final double titleHeight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Line(height: titleHeight, widthFactor: 0.25),
        const SizedBox(height: ShowDetailMetrics.sectionTitleGap),
        SizedBox(
          height: height,
          width: double.infinity,
          child: const SkeletonBox(radius: ShowDetailMetrics.cardRadius),
        ),
      ],
    );
  }
}

/// 글자 한 줄이 들어갈 자리.
class _Line extends StatelessWidget {
  const _Line({required this.height, required this.widthFactor});

  final double height;

  /// 가로 폭에서 차지하는 비율. 제목은 길고 부제는 짧아, 같은 길이로 늘어놓으면
  /// 글이 아니라 표처럼 보인다.
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: SizedBox(
        height: height,
        child: const SkeletonBox(radius: ShowDetailMetrics.badgeRadius),
      ),
    );
  }
}
