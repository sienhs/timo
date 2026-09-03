import 'package:flutter/material.dart';

import '../constants.dart';

/// 포스터 이미지를 표시할 수 없을 때 대신 그리는 자리.
class PosterPlaceholder extends StatelessWidget {
  const PosterPlaceholder({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: PaymentColors.posterPlaceholder,
      child: const Center(
        child: Icon(Icons.image_outlined, color: PaymentColors.label),
      ),
    );
  }
}
