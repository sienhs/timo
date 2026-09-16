import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class RepairStroke {
  RepairStroke(this.restore, this.width, this.points);
  final bool restore;
  final double width;
  final List<Offset> points;
}

/// Shared by the preview and exported PNG; brush coordinates follow the source.
void paintRepairedCutout(
  Canvas canvas,
  Size size,
  ui.Image source,
  ui.Image cutout,
  Rect crop,
  List<RepairStroke> strokes,
) {
  final bounds = Offset.zero & size;
  canvas.saveLayer(bounds, Paint());
  canvas.drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    bounds,
    Paint(),
  );
  canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
  canvas.drawImageRect(
    cutout,
    Rect.fromLTWH(0, 0, cutout.width.toDouble(), cutout.height.toDouble()),
    Rect.fromLTWH(
      crop.left * size.width,
      crop.top * size.height,
      crop.width * size.width,
      crop.height * size.height,
    ),
    Paint(),
  );
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;
    final paint = Paint()
      ..color = Colors.white
      ..blendMode = stroke.restore ? BlendMode.srcOver : BlendMode.clear
      ..strokeWidth = stroke.width * size.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset pixel(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final start = pixel(stroke.points.first);
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        start,
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      final path = Path()..moveTo(start.dx, start.dy);
      for (final point in stroke.points.skip(1)) {
        final p = pixel(point);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }
  canvas.restore();
  canvas.restore();
}

class CutoutRepairEditor extends StatefulWidget {
  const CutoutRepairEditor({super.key, required this.person});
  final Map<String, dynamic> person;

  @override
  State<CutoutRepairEditor> createState() => _CutoutRepairEditorState();
}

class _CutoutRepairEditorState extends State<CutoutRepairEditor> {
  ui.Image? source, cutout;
  late Rect crop;
  String? error;
  bool saving = false, showOriginal = true;
  String mode = '복원';
  double brush = 0.035;
  final strokes = <RepairStroke>[];
  final transform = TransformationController();

  @override
  void initState() {
    super.initState();
    final c = widget.person['sourceCrop'] as Map;
    crop = Rect.fromLTWH(
      (c['left'] as num).toDouble(),
      (c['top'] as num).toDouble(),
      (c['width'] as num).toDouble(),
      (c['height'] as num).toDouble(),
    );
    load();
  }

  Future<ui.Image> decode(String path) async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> load() async {
    ui.Image? original, mask;
    try {
      // Match the native pipeline's EXIF orientation and decoded dimensions.
      final path = await const MethodChannel('timo/image_pipeline')
          .invokeMethod<String>('editingSource', {
            'path': widget.person['sourcePath'],
          });
      original = await decode(path!);
      mask = await decode(widget.person['path'] as String);
      if (!mounted) {
        original.dispose();
        mask.dispose();
        return;
      }
      setState(() {
        source = original;
        cutout = mask;
      });
    } catch (_) {
      original?.dispose();
      mask?.dispose();
      if (mounted) setState(() => error = '사진을 불러오지 못했어요. 다시 열어주세요.');
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final recorder = ui.PictureRecorder();
      paintRepairedCutout(
        Canvas(recorder),
        Size(source!.width.toDouble(), source!.height.toDouble()),
        source!,
        cutout!,
        crop,
        strokes,
      );
      final picture = recorder.endRecording();
      late ui.Image output;
      try {
        output = await picture.toImage(source!.width, source!.height);
      } finally {
        picture.dispose();
      }
      late final ByteData bytes;
      try {
        bytes = (await output.toByteData(format: ui.ImageByteFormat.png))!;
      } finally {
        output.dispose();
      }
      final folder = await getApplicationDocumentsDirectory();
      final file = File(
        '${folder.path}/repair_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      if (mounted) Navigator.pop(context, file.path);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('보정을 저장하지 못했어요. 다시 시도해주세요.')),
        );
      }
    }
  }

  @override
  void dispose() {
    source?.dispose();
    cutout?.dispose();
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('누끼 보정'),
        actions: [
          TextButton(
            onPressed: source != null && !saving && strokes.isNotEmpty
                ? save
                : null,
            child: Text(saving ? '저장 중' : '적용'),
          ),
        ],
      ),
      body: source == null
          ? Center(
              child: error != null
                  ? Text(error!)
                  : const CircularProgressIndicator(),
            )
          : SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      '지워진 손을 문질러 복원하세요. 배경이 묻으면 지우기로 다듬을 수 있어요.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: const Color(0xFF414652),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = applyBoxFit(
                            BoxFit.contain,
                            Size(
                              source!.width.toDouble(),
                              source!.height.toDouble(),
                            ),
                            constraints.biggest,
                          ).destination;
                          return InteractiveViewer(
                            transformationController: transform,
                            panEnabled: mode == '확대/이동',
                            scaleEnabled: mode == '확대/이동',
                            maxScale: 8,
                            child: Center(
                              child: SizedBox.fromSize(
                                size: size,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onPanDown: mode == '확대/이동' || saving
                                      ? null
                                      : (d) => setState(() {
                                          strokes.add(
                                            RepairStroke(mode == '복원', brush, [
                                              Offset(
                                                d.localPosition.dx / size.width,
                                                d.localPosition.dy /
                                                    size.height,
                                              ),
                                            ]),
                                          );
                                        }),
                                  onPanUpdate: mode == '확대/이동' || saving
                                      ? null
                                      : (d) => setState(() {
                                          if (strokes.isNotEmpty) {
                                            strokes.last.points.add(
                                              Offset(
                                                d.localPosition.dx / size.width,
                                                d.localPosition.dy /
                                                    size.height,
                                              ),
                                            );
                                          }
                                        }),
                                  child: CustomPaint(
                                    painter: _RepairPainter(
                                      source!,
                                      cutout!,
                                      crop,
                                      strokes,
                                      showOriginal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in ['복원', '지우기', '확대/이동'])
                        ChoiceChip(
                          label: Text(value),
                          selected: mode == value,
                          onSelected: saving
                              ? null
                              : (_) => setState(() => mode = value),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      const SizedBox(width: 12),
                      const Text('붓 크기'),
                      Expanded(
                        child: Slider(
                          value: brush,
                          min: 0.005,
                          max: 0.10,
                          onChanged: saving
                              ? null
                              : (v) => setState(() => brush = v),
                        ),
                      ),
                      Icon(Icons.circle, size: brush * 220 + 3),
                      const SizedBox(width: 16),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: strokes.isEmpty || saving
                            ? null
                            : () => setState(strokes.removeLast),
                        icon: const Icon(Icons.undo),
                        label: const Text('되돌리기'),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () =>
                                  setState(() => showOriginal = !showOriginal),
                        child: Text(showOriginal ? '결과만 보기' : '원본 겹쳐 보기'),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => transform.value = Matrix4.identity(),
                        child: const Text('배율 초기화'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    ),
  );
}

class _RepairPainter extends CustomPainter {
  _RepairPainter(this.source, this.cutout, this.crop, this.strokes, this.guide);
  final ui.Image source, cutout;
  final Rect crop;
  final List<RepairStroke> strokes;
  final bool guide;
  @override
  void paint(Canvas canvas, Size size) {
    if (guide) {
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }
    paintRepairedCutout(canvas, size, source, cutout, crop, strokes);
  }

  @override
  bool shouldRepaint(covariant _RepairPainter oldDelegate) => true;
}
