import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../theme/timo_colors.dart';

/// 카탈로그를 불러오는 동안 컬렉션 화면 자리에 두는 뼈대.
///
/// [CollectionView] 가 Scaffold 째로 들고 있는 화면이라, 스피너만 두면 제목
/// 줄과 보기 전환까지 사라진다. 같은 껍데기를 세워 두고 가운데 카드 자리만
/// 비운다 — 처음 열리는 보기가 오르골("내가 만든 소장품")이어서 그 앞 카드
/// 자리에 맞춘다.
///
/// 회색은 앱 공통(`SkeletonBox`) 대신 이 화면의 종이 팔레트를 쓴다. 컬렉션과
/// 크리에이터는 나머지 화면과 다른 색 체계 위에 있다([TimoColors]).
class CollectionSkeleton extends StatelessWidget {
  const CollectionSkeleton({super.key});

  /// 가운데 카드가 차지하는 가로 폭. 오르골 앞 카드와 같은 비율이다.
  static const _cardWidthFactor = CollectionLayout.orgelCardWidthFactor;

  /// 보기 전환 글자 한 개의 폭.
  static const _filterLabelWidth = 108.0;
  static const _filterLabelHeight = 13.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(CollectionText.title)),
      body: SafeArea(
        child: Semantics(
          label: CollectionText.loading,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  CollectionLayout.pagePadding,
                  6,
                  CollectionLayout.pagePadding,
                  6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _Box(
                      width: _filterLabelWidth,
                      height: _filterLabelHeight,
                      radius: 4,
                    ),
                    SizedBox(width: 21),
                    _Box(
                      width: _filterLabelWidth / 2,
                      height: _filterLabelHeight,
                      radius: 4,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: _cardWidthFactor,
                    child: const AspectRatio(
                      aspectRatio: CollectionLayout.cardAspect,
                      child: _Box(radius: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이 화면의 종이 팔레트로 칠한 빈 자리.
class _Box extends StatelessWidget {
  const _Box({this.width, this.height, required this.radius});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: TimoColors.paperMuted,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
