import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../theme/timo_colors.dart';
import '../ui/paper_card.dart';

/// 고를 공연을 불러오는 동안 [ConcertCard] 자리에 두는 빈 카드들.
///
/// 껍데기는 실제 카드와 같은 [PaperCard] 를 쓰고 안쪽 여백·포스터 크기도 같게
/// 잡는다. 소장품 만들기의 첫 단계라 목록이 뜨기 전에는 할 수 있는 일이
/// 없는데, 스피너만 돌면 이 화면이 무엇을 고르는 자리인지 보이지 않는다.
///
/// 회색은 이 화면의 종이 팔레트를 쓴다([TimoColors]) — 컬렉션 · 크리에이터는
/// 앱의 나머지와 다른 색 체계 위에 있다.
class ConcertListSkeleton extends StatelessWidget {
  const ConcertListSkeleton({super.key});

  /// 폰 한 화면에 들어가는 만큼.
  static const _count = 3;

  /// 실제 카드와 같은 값들.
  static const _cardPadding = 14.0;
  static const _cardGap = 14.0;
  static const _posterWidth = 64.0;
  static const _posterHeight = 88.0;
  static const _posterGap = 14.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: CreatorText.loadingConcerts,
      child: Column(
        children: [
          for (var i = 0; i < _count; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: _cardGap),
              child: PaperCard(
                padding: EdgeInsets.all(_cardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Box(width: _posterWidth, height: _posterHeight, radius: 8),
                    SizedBox(width: _posterGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Line(height: 16, widthFactor: 0.8),
                          SizedBox(height: 10),
                          _Line(height: 13, widthFactor: 0.55),
                          SizedBox(height: 6),
                          _Line(height: 13, widthFactor: 0.4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
      child: _Box(height: height, radius: 4),
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
