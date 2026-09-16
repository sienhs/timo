import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../effects/shader_cache.dart';
import '../ui/local_image.dart';
import '../../constants.dart';
import '../../effects/volumetric_light.dart';

/// 2.5D photo. With a depth map the fragment shader displaces every pixel by
/// its depth; otherwise (or while decoding) the three soft depth bands from
/// the native pipeline are translated as separate layers. Tilt arrives as a
/// listenable so the painter repaints without rebuilding the widget.
class DepthPhoto extends StatefulWidget {
  const DepthPhoto({
    super.key,
    required this.backgroundPath,
    required this.depthMapPath,
    required this.layers,
    required this.tilt,
    this.preserveFraming = false,
    this.haze,
  });
  final String backgroundPath;
  final String? depthMapPath;
  final List<String> layers;
  final ValueListenable<Offset> tilt;
  final bool preserveFraming;

  /// Aerial perspective for the volumetric light: far pixels (from the
  /// depth map) lose contrast and take the light's colour. Null = off.
  /// Without a depth map the band fallback approximates "far" as "top".
  final ValueListenable<VolumetricLightParams>? haze;
  static const _shader = 'shaders/depth_parallax.frag';
  @override
  State<DepthPhoto> createState() => _DepthPhotoState();
}

class _DepthPhotoState extends State<DepthPhoto> {
  ui.Image? photo, depth;
  @override
  void initState() {
    super.initState();
    decode();
  }

  Future<void> decode() async {
    final depthPath = widget.depthMapPath;
    if (depthPath == null) return;
    try {
      final images = await Future.wait([
        _decodeFile(widget.backgroundPath),
        _decodeFile(depthPath),
      ]);
      if (!mounted) {
        for (final i in images) {
          i.dispose();
        }
        return;
      }
      setState(() {
        photo = images[0];
        depth = images[1];
      });
    } catch (_) {
      // Band layers remain on screen.
    }
  }

  static Future<ui.Image> _decodeFile(String path) async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  @override
  void dispose() {
    photo?.dispose();
    depth?.dispose();
    super.dispose();
  }

  Widget bands() => _BandLayers(
    backgroundPath: widget.backgroundPath,
    layers: widget.layers,
    tilt: widget.tilt,
    preserveFraming: widget.preserveFraming,
    haze: widget.haze,
  );
  @override
  Widget build(BuildContext context) {
    if (photo == null || depth == null) return bands();
    return ShaderBuilder(
      asset: DepthPhoto._shader,
      fallback: bands(),
      builder: (_, shader) => RepaintBoundary(
        child: CustomPaint(
          painter: _DepthPainter(
            shader,
            photo!,
            depth!,
            widget.tilt,
            widget.preserveFraming,
            widget.haze,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DepthPainter extends CustomPainter {
  _DepthPainter(
    this.shader,
    this.photo,
    this.depth,
    this.tilt,
    this.preserveFraming,
    this.haze,
  ) : super(repaint: haze == null ? tilt : Listenable.merge([tilt, haze]));
  final ui.FragmentShader shader;
  final ui.Image photo, depth;
  final ValueListenable<Offset> tilt;
  final bool preserveFraming;
  final ValueListenable<VolumetricLightParams>? haze;
  final _paint = Paint();
  @override
  void paint(Canvas canvas, Size size) {
    final shift =
        tilt.value / ViewerConstants.maxTilt * ViewerConstants.depthShift;
    final h = haze?.value;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, shift.dx)
      ..setFloat(3, shift.dy)
      ..setFloat(4, _zoom(tilt.value, preserveFraming))
      ..setFloat(5, photo.width.toDouble())
      ..setFloat(6, photo.height.toDouble())
      ..setFloat(7, h?.farHaze ?? 0)
      ..setFloat(8, h?.color.r ?? 0)
      ..setFloat(9, h?.color.g ?? 0)
      ..setFloat(10, h?.color.b ?? 0)
      ..setImageSampler(0, photo)
      ..setImageSampler(1, depth);
    _paint.shader = shader;
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(_DepthPainter old) =>
      old.tilt != tilt ||
      old.photo != photo ||
      old.depth != depth ||
      old.preserveFraming != preserveFraming ||
      old.haze != haze;
}

// At rest the saved crop is shown exactly; overscan only accompanies tilt.
double _zoom(Offset tilt, bool preserveFraming) => preserveFraming
    ? 1 +
          (ViewerConstants.depthZoom - 1) *
              (tilt.distance / ViewerConstants.maxTilt).clamp(0, 1)
    : ViewerConstants.depthZoom;

class _BandLayers extends StatelessWidget {
  const _BandLayers({
    required this.backgroundPath,
    required this.layers,
    required this.tilt,
    required this.preserveFraming,
    this.haze,
  });
  final String backgroundPath;
  final List<String> layers;
  final ValueListenable<Offset> tilt;
  final bool preserveFraming;
  final ValueListenable<VolumetricLightParams>? haze;
  Widget layer(String path, double strength) => Positioned.fill(
    child: ValueListenableBuilder<Offset>(
      valueListenable: tilt,
      builder: (_, t, child) => Transform.translate(
        offset: t * strength,
        child: Transform.scale(scale: _zoom(t, preserveFraming), child: child),
      ),
      child: LocalImage(path),
    ),
  );
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: Color(0xFF0B0F1A)),
      layer(backgroundPath, ViewerConstants.parallax[0]),
      for (var i = 0; i < layers.length; i++)
        layer(layers[i], ViewerConstants.parallax[i + 1]),
      // No depth map: the top of the stage is the far end of the room.
      if (haze != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<VolumetricLightParams>(
              valueListenable: haze!,
              builder: (_, v, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      v.color.withValues(alpha: 0.30 * v.farHaze),
                      v.color.withValues(alpha: 0.10 * v.farHaze),
                      v.color.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45, 0.8],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
