import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/person_depth_layer.dart';
import '../../effects/shader_cache.dart';
import '../ui/local_image.dart';
import '../../constants.dart';

class PersonDepthPhoto extends StatefulWidget {
  const PersonDepthPhoto({super.key, required this.layer, required this.tilt});
  final PersonDepthLayer layer;
  final ValueListenable<Offset> tilt;

  static const singleShader = 'shaders/person_depth.frag';
  static const layeredShader = 'shaders/person_layers.frag';

  @override
  State<PersonDepthPhoto> createState() => _PersonDepthPhotoState();
}

class _PersonDepthPhotoState extends State<PersonDepthPhoto> {
  ui.Image? photo, depth, parts;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    decode();
  }

  @override
  void didUpdateWidget(PersonDepthPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layer.path != widget.layer.path ||
        oldWidget.layer.depthMapPath != widget.layer.depthMapPath ||
        oldWidget.layer.partMapPath != widget.layer.partMapPath ||
        oldWidget.layer.usesPartLayers != widget.layer.usesPartLayers) {
      decode();
    }
  }

  static Future<ui.Image> read(String path) async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  void release() {
    photo?.dispose();
    depth?.dispose();
    parts?.dispose();
    photo = null;
    depth = null;
    parts = null;
  }

  Future<void> decode() async {
    final id = ++generation;
    release();
    final path = widget.layer.depthMapPath;
    if (path == null) return;
    final loaded = <ui.Image>[];
    try {
      loaded.add(await read(widget.layer.path));
      loaded.add(await read(path));
      if (widget.layer.usesPartLayers) {
        // A missing part map degrades to the single-map shader, not to a
        // still image.
        try {
          loaded.add(await read(widget.layer.partMapPath!));
        } catch (_) {}
      }
      if (!mounted || id != generation) return;
      setState(() {
        photo = loaded[0];
        depth = loaded[1];
        parts = loaded.length > 2 ? loaded[2] : null;
      });
      loaded.clear();
    } catch (_) {
      // A missing cache or shader never hides the person's original cutout.
    } finally {
      for (final image in loaded) {
        image.dispose();
      }
    }
  }

  @override
  void dispose() {
    generation++;
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = LocalImage(widget.layer.path, fit: BoxFit.fill);
    if (photo == null ||
        depth == null ||
        widget.layer.strength == PersonDepthStrength.off) {
      return fallback;
    }
    final asset = parts == null
        ? PersonDepthPhoto.singleShader
        : PersonDepthPhoto.layeredShader;
    return ShaderBuilder(
      key: ValueKey(asset),
      asset: asset,
      fallback: fallback,
      builder: (_, shader) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PersonDepthPainter(
            shader,
            photo!,
            depth!,
            parts,
            parts == null ? const [] : widget.layer.parts,
            widget.tilt,
            widget.layer.strength,
          ),
        ),
      ),
    );
  }
}

class _PersonDepthPainter extends CustomPainter {
  _PersonDepthPainter(
    this.shader,
    this.photo,
    this.depth,
    this.parts,
    this.layers,
    this.tilt,
    this.strength,
  ) : super(repaint: tilt);
  final ui.FragmentShader shader;
  final ui.Image photo, depth;

  /// Part map and its layers (far to near); null draws the single-map shader.
  final ui.Image? parts;
  final List<PersonPart> layers;
  final ValueListenable<Offset> tilt;
  final PersonDepthStrength strength;
  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, (tilt.value.dx / ViewerConstants.maxTilt).clamp(-1, 1))
      ..setFloat(3, (tilt.value.dy / ViewerConstants.maxTilt).clamp(-1, 1))
      ..setFloat(4, strength.displacement)
      ..setImageSampler(0, photo)
      ..setImageSampler(1, depth);
    final parts = this.parts;
    if (parts != null) {
      setLayerUniforms(shader, layers);
      shader.setImageSampler(2, parts);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  /// Uniform slots 5–11 of `person_layers.frag`.
  static void setLayerUniforms(
    ui.FragmentShader shader,
    List<PersonPart> layers,
  ) {
    shader
      ..setFloat(5, ViewerConstants.personLayerGain)
      ..setFloat(6, ViewerConstants.personReliefGain)
      ..setFloat(7, layers.length.toDouble());
    for (var k = 0; k < 4; k++) {
      shader.setFloat(8 + k, k < layers.length ? layers[k].depth : 0.5);
    }
  }

  @override
  bool shouldRepaint(_PersonDepthPainter old) =>
      old.photo != photo ||
      old.depth != depth ||
      old.parts != parts ||
      old.tilt != tilt ||
      old.strength != strength;
}

class PersonDepthStack extends StatelessWidget {
  const PersonDepthStack({super.key, required this.layers, required this.tilt});
  final List<PersonDepthLayer> layers;
  final ValueListenable<Offset> tilt;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ordered = layers.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return Stack(
        children: [
          for (final layer in ordered)
            Positioned(
              left: layer.placement.left * constraints.maxWidth,
              top: layer.placement.top * constraints.maxHeight,
              width: layer.placement.width * constraints.maxWidth,
              height: layer.placement.height * constraints.maxHeight,
              child: PersonDepthPhoto(
                key: ValueKey(layer.path),
                layer: layer,
                tilt: tilt,
              ),
            ),
        ],
      );
    },
  );
}
