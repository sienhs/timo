import 'dart:io';

import 'package:flutter/material.dart';

class LocalImage extends StatelessWidget {
  const LocalImage(
    this.path, {
    super.key,
    this.fit = BoxFit.contain,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
  });
  final String path;
  final BoxFit fit;

  /// Decode at a small width to get a cheap, naturally blurred backdrop.
  final int? cacheWidth;
  final FilterQuality filterQuality;
  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    fit: fit,
    cacheWidth: cacheWidth,
    filterQuality: filterQuality,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const Center(child: Text('사진을 불러올 수 없어요')),
  );
}
