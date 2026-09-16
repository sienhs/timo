import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Compiles each fragment program once per process.
class ShaderCache {
  static final _programs = <String, Future<ui.FragmentProgram>>{};
  static Future<ui.FragmentProgram> load(String asset) =>
      _programs.putIfAbsent(asset, () => ui.FragmentProgram.fromAsset(asset));
}

/// Hands a ready [ui.FragmentShader] to [builder]; renders [fallback] while
/// compiling or when the platform cannot run the shader.
class ShaderBuilder extends StatefulWidget {
  const ShaderBuilder({
    super.key,
    required this.asset,
    required this.builder,
    required this.fallback,
  });
  final String asset;
  final Widget Function(BuildContext context, ui.FragmentShader shader) builder;
  final Widget fallback;
  @override
  State<ShaderBuilder> createState() => _ShaderBuilderState();
}

class _ShaderBuilderState extends State<ShaderBuilder> {
  ui.FragmentShader? shader;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    ShaderCache.load(widget.asset)
        .then((program) {
          if (mounted) setState(() => shader = program.fragmentShader());
        })
        .catchError((Object _) {
          if (mounted) setState(() => failed = true);
        });
  }

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => shader == null || failed
      ? widget.fallback
      : widget.builder(context, shader!);
}
