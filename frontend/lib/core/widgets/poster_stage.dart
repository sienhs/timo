import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'poster_image.dart';

/// 포스터를 자르지 않고 보여 주는 칸. 세로로 긴 포스터를 세로에 맞춰 통째로
/// 넣고 남는 좌우는 같은 포스터를 흐리게 깐 배경으로 메운다. 크기는 부모가
/// 정하고, [child] 를 주면 포스터 위에 겹쳐 그린다.
class PosterStage extends StatelessWidget {
  const PosterStage({
    super.key,
    required this.url,
    required this.verticalInset,
    this.borderRadius = 0,
    this.child,
  });

  /// 서버가 준 포스터 주소. 없으면 [PosterImage] 가 회색 자리를 그린다.
  final String? url;

  /// 포스터 위아래로 남기는 여백. 0 이면 포스터가 칸 높이를 꽉 채워 위아래
  /// 끝이 모서리에 붙는데, 조금 띄워야 배경 위에 얹힌 한 장으로 읽힌다.
  final double verticalInset;

  final double borderRadius;

  /// 포스터 위에 겹칠 내용(제목 묶음 등). 칸 전체를 받는다.
  final Widget? child;

  /// 배경 블러의 세기. 더 약하면 뒤에 깔린 그림의 윤곽이 읽혀 앞의 포스터와
  /// 겹쳐 보이고, 더 세면 그냥 한 가지 색이 되어 포스터가 번진 느낌이 사라진다.
  static const _blurSigma = 28.0;

  /// 배경을 조금 키워서 깐다. 블러는 가장자리 바깥을 참조할 수 없어 테두리가
  /// 옅어지는데, 칸보다 크게 그려 그 부분을 칸 밖으로 밀어낸다.
  static const _backgroundScale = 1.2;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: _backgroundScale,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: _blurSigma,
                sigmaY: _blurSigma,
                tileMode: TileMode.clamp,
              ),
              child: PosterImage.network(
                url: url,
                // 어차피 흐려질 그림이라 원본 크기로 디코딩할 이유가 없다.
                decodeWidth: MediaQuery.sizeOf(context).width / 2,
              ),
            ),
          ),
          // 배경이 밝은 포스터면 앞의 포스터와 경계가 흐려진다. 살짝 덮어
          // 앞뒤를 갈라 준다.
          const ColoredBox(color: Colors.black26, child: SizedBox.expand()),
          Padding(
            padding: EdgeInsets.symmetric(vertical: verticalInset),
            child: PosterImage.network(
              url: url,
              fit: BoxFit.contain,
              decodeWidth: MediaQuery.sizeOf(context).width,
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
