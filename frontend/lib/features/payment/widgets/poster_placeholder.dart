import 'package:flutter/material.dart';

import '../constants.dart';

/// 포스터 이미지를 표시할 수 없을 때 대신 그리는 자리.
class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({
    super.key,
    required this.width,
    required this.height,
  }) : _showIcon = true;

  /// 그림이 아직 오는 중일 때의 자리. 아이콘을 빼서 '못 읽은 그림' 과 갈라
  /// 둔다 — 오는 중인데 그림 아이콘이 떠 있으면 실패한 것으로 읽힌다.
  const PosterPlaceholder.loading({
    super.key,
    required this.width,
    required this.height,
  }) : _showIcon = false;

  final double width;
  final double height;

  final bool _showIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: PaymentColors.posterPlaceholder,
      child: _showIcon
          ? const Center(
              child: Icon(Icons.image_outlined, color: PaymentColors.label),
            )
          : null,
    );
  }
}
