import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../effects/shader_cache.dart';
import '../../effects/volumetric_light.dart';

/// Rim light on the contour of the person cut-out that faces the volumetric
/// fixture. The shader reads the composite's alpha mask, so only the edge
/// toward the light is lit and the face and clothes stay untouched. The
/// image comes from the same [ImageCache] entry the person layer paints, so
/// there is no second decode; it is drawn additively in the exact rect a
/// contain-fit [Image] occupies.
class PersonRimLight extends StatefulWidget {
  const PersonRimLight({super.key, required this.path, this.params});
  final String path;

  /// Live parameters; defaults to [VolumetricLightController.instance].
  final ValueListenable<VolumetricLightParams>? params;
  static const shaderAsset = 'shaders/rim_light.frag';
  @override
  State<PersonRimLight> createState() => _PersonRimLightState();
}

class _PersonRimLightState extends State<PersonRimLight> {
  ImageStream? stream;
  ImageStreamListener? listener;
  ui.Image? image;

  @override
  void initState() {
    super.initState();
    resolve();
  }

  @override
  void didUpdateWidget(PersonRimLight old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) resolve();
  }

  void resolve() {
    release();
    final s = FileImage(File(widget.path)).resolve(ImageConfiguration.empty);
    final l = ImageStreamListener(
      (info, _) {
        final next = info.image.clone();
        info.dispose();
        if (!mounted) {
          next.dispose();
          return;
        }
        setState(() {
          image?.dispose();
          image = next;
        });
      },
      onError: (_, _) {
        // No mask, no rim: the person's original cut-out is untouched.
      },
    );
    s.addListener(l);
    stream = s;
    listener = l;
  }

  void release() {
    final s = stream, l = listener;
    if (s != null && l != null) s.removeListener(l);
    stream = null;
    listener = null;
    image?.dispose();
    image = null;
  }

  @override
  void dispose() {
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img == null) return const SizedBox.expand();
    return IgnorePointer(
      child: ShaderBuilder(
        asset: PersonRimLight.shaderAsset,
        fallback: const SizedBox.expand(),
        builder: (_, shader) => CustomPaint(
          size: Size.infinite,
          painter: _RimPainter(
            shader,
            img,
            widget.params ?? VolumetricLightController.instance,
          ),
        ),
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  _RimPainter(this.shader, this.image, this.params) : super(repaint: params);
  final ui.FragmentShader shader;
  final ui.Image image;
  final ValueListenable<VolumetricLightParams> params;
  final _paint = Paint()..blendMode = BlendMode.plus;

  /// How much more the top of the silhouette catches than the feet.
  static const topBias = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final v = params.value;
    if (v.rimIntensity <= 0 || size.isEmpty) return;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, imageSize, size);
    final dest = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    shader
      ..setFloat(0, dest.left)
      ..setFloat(1, dest.top)
      ..setFloat(2, dest.width)
      ..setFloat(3, dest.height)
      ..setFloat(4, v.lightX)
      ..setFloat(5, v.lightY)
      ..setFloat(6, v.rimWidth)
      ..setFloat(7, v.color.r)
      ..setFloat(8, v.color.g)
      ..setFloat(9, v.color.b)
      ..setFloat(10, v.rimIntensity)
      ..setFloat(11, topBias)
      ..setImageSampler(0, image);
    _paint.shader = shader;
    canvas.drawRect(dest, _paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.image != image || old.params != params || old.shader != shader;
}
