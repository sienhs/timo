import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/photo_framing.dart';
import '../../constants.dart';

class PhotoFrame extends StatefulWidget {
  const PhotoFrame({
    super.key,
    required this.path,
    required this.framing,
    this.onChanged,
  });
  final String path;
  final PhotoFraming framing;
  final ValueChanged<PhotoFraming>? onChanged;

  @override
  State<PhotoFrame> createState() => _PhotoFrameState();
}

class _PhotoFrameState extends State<PhotoFrame> {
  ui.Image? image;
  bool failed = false;
  int request = 0;
  double startScale = 1;

  @override
  void initState() {
    super.initState();
    decode();
  }

  @override
  void didUpdateWidget(PhotoFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) decode();
  }

  Future<void> decode() async {
    final seq = ++request;
    image?.dispose();
    image = null;
    failed = false;
    try {
      final codec = await ui.instantiateImageCodec(
        await File(widget.path).readAsBytes(),
      );
      late final ui.Image decoded;
      try {
        decoded = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted || seq != request) {
        decoded.dispose();
        return;
      }
      setState(() => image = decoded);
    } catch (_) {
      if (mounted && seq == request) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: ViewerConstants.cardAspect,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final photo = image;
        if (photo == null) {
          return Center(
            child: failed
                ? const Text('사진을 불러올 수 없어요. 다시 선택해주세요.')
                : const CircularProgressIndicator(),
          );
        }
        final frame = constraints.biggest;
        final editable = widget.onChanged != null && !widget.framing.contain;
        return Semantics(
          label: editable ? '티켓 사진 구도. 드래그로 이동하고 두 손가락으로 확대하세요.' : '티켓 사진 미리보기',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: editable
                ? (_) => startScale = widget.framing.scale
                : null,
            onScaleUpdate: editable
                ? (details) {
                    final next = widget.framing.copyWith(
                      scale: startScale * details.scale,
                    );
                    final rect = next.destination(
                      Size(photo.width.toDouble(), photo.height.toDouble()),
                      frame,
                    );
                    final overflowX = rect.width - frame.width;
                    final overflowY = rect.height - frame.height;
                    widget.onChanged!(
                      next.copyWith(
                        x: overflowX > 0.01
                            ? next.x -
                                  2 * details.focalPointDelta.dx / overflowX
                            : 0,
                        y: overflowY > 0.01
                            ? next.y -
                                  2 * details.focalPointDelta.dy / overflowY
                            : 0,
                      ),
                    );
                  }
                : null,
            child: CustomPaint(
              painter: _PhotoPainter(photo, widget.framing),
              size: frame,
            ),
          ),
        );
      },
    ),
  );
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.image, this.framing);
  final ui.Image image;
  final PhotoFraming framing;
  @override
  void paint(Canvas canvas, Size size) => framing.paint(canvas, image, size);
  @override
  bool shouldRepaint(_PhotoPainter old) =>
      old.image != image || old.framing != framing;
}
