import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

import '../models/person_depth_layer.dart';
import '../constants.dart';

typedef _K = PersonLayeringConstants;

/// A pose landmark in cutout-normalised coordinates with its visibility.
class Landmark {
  const Landmark(this.x, this.y, this.v);
  final double x, y, v;

  /// Parses the list `PersonProcessor.analyze` returns under `landmarks`.
  static List<Landmark>? parse(Object? raw) {
    if (raw is! List || raw.length < 33) return null;
    return [
      for (final p in raw)
        Landmark(
          ((p as Map)['x'] as num).toDouble(),
          (p['y'] as num).toDouble(),
          (p['v'] as num).toDouble(),
        ),
    ];
  }
}

/// Pixel data the isolate works on: the cutout's alpha, the aligned depth
/// map's red channel (0 = far, 255 = near, 128 outside), and the pose.
class PartMapInput {
  const PartMapInput({
    required this.width,
    required this.height,
    required this.alpha,
    required this.depth,
    required this.landmarks,
  });
  final int width, height;
  final Uint8List alpha, depth;
  final List<Landmark> landmarks;
}

/// The part map at working resolution: RGB = weights of the far layers,
/// alpha always opaque; the nearest layer is the remainder.
class PartMapResult {
  const PartMapResult({
    required this.width,
    required this.height,
    required this.rgba,
    required this.layers,
  });
  final int width, height;
  final Uint8List rgba;
  final List<PersonPart> layers;
}

class PersonLayeringResult {
  const PersonLayeringResult({required this.partMapPath, required this.layers});
  final String partMapPath;
  final List<PersonPart> layers;
}

/// Splits a person's depth map into body-part layers on the Dart side.
/// Inference stays native; this only needs files that already exist.
class PersonLayering {
  /// Null whenever a split is not possible (no pose, one part, unreadable
  /// files). Callers keep the single-map depth in that case.
  Future<PersonLayeringResult?> build({
    required String cutoutPath,
    required String depthMapPath,
    required Map<String, dynamic> analysis,
  }) async {
    final landmarks = Landmark.parse(analysis['landmarks']);
    if (landmarks == null) return null;
    try {
      final input = await _readInput(cutoutPath, depthMapPath, landmarks);
      if (input == null) return null;
      final result = await Isolate.run(() => computePartMap(input));
      if (result == null) return null;
      return PersonLayeringResult(
        partMapPath: await _savePng(result),
        layers: result.layers,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _decode(String path) async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  static Future<PartMapInput?> _readInput(
    String cutoutPath,
    String depthMapPath,
    List<Landmark> landmarks,
  ) async {
    final cutout = await _decode(cutoutPath);
    final depth = await _decode(depthMapPath);
    try {
      if (cutout.width != depth.width || cutout.height != depth.height) {
        return null;
      }
      final count = cutout.width * cutout.height;
      final cutoutBytes = (await cutout.toByteData())!;
      final depthBytes = (await depth.toByteData())!;
      final alpha = Uint8List(count);
      final depthValues = Uint8List(count);
      for (var i = 0; i < count; i++) {
        alpha[i] = cutoutBytes.getUint8(i * 4 + 3);
        depthValues[i] = depthBytes.getUint8(i * 4);
      }
      return PartMapInput(
        width: cutout.width,
        height: cutout.height,
        alpha: alpha,
        depth: depthValues,
        landmarks: landmarks,
      );
    } finally {
      cutout.dispose();
      depth.dispose();
    }
  }

  static Future<String> _savePng(PartMapResult result) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      result.rgba,
      result.width,
      result.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      final root = await getApplicationDocumentsDirectory();
      final folder = await Directory('${root.path}/person_layers')
          .create(recursive: true);
      final file = File(
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      return file.path;
    } finally {
      image.dispose();
    }
  }
}

/// Pure function so it can run in an isolate and in desktop tests.
/// Returns null when fewer than two layers can be told apart.
PartMapResult? computePartMap(PartMapInput input) {
  final grid = _Grid.downsample(input);
  final pose = _Pose(input.landmarks, grid.width, grid.height);
  final shoulder = pose.shoulderWidth();
  if (shoulder == null) return null;
  final parts = _Part.build(pose, shoulder, grid.height);
  if (parts.map((p) => p.group).toSet().length < 2) return null;

  // Geometric cost per part and pixel; the depth term is added later.
  final geometric = [for (final _ in parts) Float32List(grid.count)];
  for (var i = 0; i < grid.count; i++) {
    if (!grid.inside[i]) continue;
    final x = (i % grid.width) + 0.5, y = (i ~/ grid.width) + 0.5;
    for (var k = 0; k < parts.length; k++) {
      geometric[k][i] = parts[k].cost(x, y);
    }
  }
  // First pass: distance only, to learn each part's typical depth.
  final histograms = [for (final _ in parts) Uint32List(256)];
  for (var i = 0; i < grid.count; i++) {
    if (!grid.inside[i]) continue;
    var best = -1;
    var bestCost = double.infinity;
    for (var k = 0; k < parts.length; k++) {
      final cost = geometric[k][i];
      if (cost < bestCost) {
        bestCost = cost;
        best = k;
      }
    }
    if (best >= 0 && bestCost <= 1) histograms[best][grid.depth[i]]++;
  }
  final active = List<bool>.filled(parts.length, true);
  final medians = List<double>.filled(parts.length, 128);
  for (var k = 0; k < parts.length; k++) {
    final total = histograms[k].fold<int>(0, (a, b) => a + b);
    if (total < _K.minPartPixels) {
      active[k] = false;
    } else {
      medians[k] = _median(histograms[k], total).toDouble();
    }
  }

  // Second pass: geometry plus depth similarity, then fold tiny layers away.
  final labels = Int8List(grid.count);
  final groups = parts.map((p) => p.group).toSet().toList();
  List<_Layer> layers;
  while (true) {
    for (var i = 0; i < grid.count; i++) {
      if (!grid.inside[i]) {
        labels[i] = -1;
        continue;
      }
      var best = -1;
      var bestCost = double.infinity;
      for (var k = 0; k < parts.length; k++) {
        if (!active[k]) continue;
        final dz = (grid.depth[i] - medians[k]) / 255;
        final cost = geometric[k][i] + _K.depthWeight * dz * dz;
        if (cost < bestCost) {
          bestCost = cost;
          best = k;
        }
      }
      labels[i] = best;
    }
    layers = _Layer.collect(groups, parts, labels, grid);
    final drop = _redundantLayer(layers);
    if (drop == null) break;
    for (var k = 0; k < parts.length; k++) {
      if (parts[k].group == drop) active[k] = false;
    }
  }
  if (layers.length < 2) return null;
  layers.sort((a, b) => a.depth.compareTo(b.depth));
  final layerOfPart = List<int>.filled(parts.length, -1);
  for (var k = 0; k < parts.length; k++) {
    layerOfPart[k] = layers.indexWhere((l) => l.group == parts[k].group);
  }

  // Hard labels → soft weights, feathered, then pushed past the outline.
  final weights = [for (final _ in layers) Float32List(grid.count)];
  for (var i = 0; i < grid.count; i++) {
    final label = labels[i];
    if (label < 0) continue;
    final layer = layerOfPart[label];
    if (layer >= 0) weights[layer][i] = 1;
  }
  final filled = List<bool>.of(grid.inside);
  for (var pass = 0; pass < _K.featherPasses; pass++) {
    _blur(weights, filled, grid.width, grid.height, onlyFilled: true);
  }
  for (var pass = 0; pass < _K.dilatePasses; pass++) {
    _dilate(weights, filled, grid.width, grid.height);
  }

  final rgba = Uint8List(grid.count * 4);
  for (var i = 0; i < grid.count; i++) {
    for (var k = 0; k < layers.length - 1 && k < 3; k++) {
      rgba[i * 4 + k] = (weights[k][i] * 255).round().clamp(0, 255);
    }
    rgba[i * 4 + 3] = 255;
  }
  return PartMapResult(
    width: grid.width,
    height: grid.height,
    rgba: rgba,
    layers: [
      for (final layer in layers)
        PersonPart(
          label: layer.group,
          depth: layer.depth / 255,
          share: layer.share,
        ),
    ],
  );
}

/// A layer that adds nothing: too small, or so close in depth to its
/// neighbour that the two would slide together anyway (the smaller goes).
String? _redundantLayer(List<_Layer> layers) {
  if (layers.length <= 1) return null;
  for (final layer in layers) {
    if (layer.share < _K.minLayerShare) return layer.group;
  }
  final sorted = layers.toList()..sort((a, b) => a.depth.compareTo(b.depth));
  var closest = -1;
  var gap = double.infinity;
  for (var i = 1; i < sorted.length; i++) {
    final d = sorted[i].depth - sorted[i - 1].depth;
    if (d < gap) {
      gap = d;
      closest = i;
    }
  }
  // Over the shader's four slots, the most similar neighbours merge first.
  if (closest < 0 ||
      (gap >= _K.minLayerDepthGap && sorted.length <= _K.maxLayers)) {
    return null;
  }
  final far = sorted[closest - 1], near = sorted[closest];
  return near.share < far.share ? near.group : far.group;
}

int _median(Uint32List histogram, int total) {
  var seen = 0;
  for (var v = 0; v < 256; v++) {
    seen += histogram[v];
    if (seen * 2 >= total) return v;
  }
  return 255;
}

/// 3×3 box blur of every weight map, renormalised so they still sum to one.
void _blur(
  List<Float32List> weights,
  List<bool> filled,
  int width,
  int height, {
  required bool onlyFilled,
}) {
  final copies = [for (final w in weights) Float32List.fromList(w)];
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      if (!filled[i]) continue;
      var sum = 0.0;
      final acc = List<double>.filled(weights.length, 0);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final j = ny * width + nx;
          if (onlyFilled && !filled[j]) continue;
          for (var k = 0; k < weights.length; k++) {
            acc[k] += copies[k][j];
            sum += copies[k][j];
          }
        }
      }
      if (sum <= 0) continue;
      for (var k = 0; k < weights.length; k++) {
        weights[k][i] = acc[k] / sum;
      }
    }
  }
}

/// Copies the average of filled neighbours into unfilled pixels touching them.
void _dilate(
  List<Float32List> weights,
  List<bool> filled,
  int width,
  int height,
) {
  final grown = List<bool>.of(filled);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x;
      if (filled[i]) continue;
      var sum = 0.0;
      final acc = List<double>.filled(weights.length, 0);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          final j = ny * width + nx;
          if (!filled[j]) continue;
          for (var k = 0; k < weights.length; k++) {
            acc[k] += weights[k][j];
            sum += weights[k][j];
          }
        }
      }
      if (sum <= 0) continue;
      for (var k = 0; k < weights.length; k++) {
        weights[k][i] = acc[k] / sum;
      }
      grown[i] = true;
    }
  }
  filled.setAll(0, grown);
}

/// The cutout reduced to the working grid: per-pixel inside flag and the
/// mean depth of its foreground source pixels.
class _Grid {
  _Grid(this.width, this.height)
    : count = width * height,
      inside = List<bool>.filled(width * height, false),
      depth = Uint8List(width * height);
  final int width, height, count;
  final List<bool> inside;
  final Uint8List depth;

  static _Grid downsample(PartMapInput input) {
    final scale = math.max(
      1.0,
      math.max(input.width, input.height) / _K.workingLongSide,
    );
    final grid = _Grid(
      (input.width / scale).ceil(),
      (input.height / scale).ceil(),
    );
    for (var gy = 0; gy < grid.height; gy++) {
      final y0 = (gy * scale).floor();
      final y1 = math.max(
        y0 + 1,
        math.min(input.height, ((gy + 1) * scale).floor()),
      );
      for (var gx = 0; gx < grid.width; gx++) {
        final x0 = (gx * scale).floor();
        final x1 = math.max(
          x0 + 1,
          math.min(input.width, ((gx + 1) * scale).floor()),
        );
        var alphaSum = 0, depthSum = 0, foreground = 0, pixels = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final i = y * input.width + x;
            alphaSum += input.alpha[i];
            pixels++;
            if (input.alpha[i] > _K.foregroundAlpha) {
              depthSum += input.depth[i];
              foreground++;
            }
          }
        }
        final g = gy * grid.width + gx;
        grid.inside[g] = pixels > 0 && alphaSum / pixels > _K.insideAlpha;
        grid.depth[g] = foreground > 0 ? depthSum ~/ foreground : 128;
      }
    }
    return grid;
  }
}

class _Pose {
  _Pose(this.points, this.width, this.height);
  final List<Landmark> points;
  final int width, height;

  bool visible(int i) {
    final p = points[i];
    return p.v >= _K.visibleLandmark &&
        p.x >= -_K.landmarkMargin &&
        p.x <= 1 + _K.landmarkMargin &&
        p.y >= -_K.landmarkMargin &&
        p.y <= 1 + _K.landmarkMargin;
  }

  math.Point<double> at(int i) =>
      math.Point(points[i].x * width, points[i].y * height);

  double distance(int a, int b) => at(a).distanceTo(at(b));

  /// Shoulder width in working pixels, estimated from the ears or the image
  /// when the shoulders are hidden. Null without any usable cue.
  double? shoulderWidth() {
    double? width;
    if (visible(11) && visible(12)) {
      width = distance(11, 12);
    } else if (visible(7) && visible(8)) {
      width = distance(7, 8) * _K.shoulderFromEars;
    } else if (visible(0)) {
      width = this.width * _K.shoulderFromWidth;
    }
    if (width == null) return null;
    return math.max(width, this.width * _K.minShoulderFraction);
  }
}

/// One skeleton piece: capsules (segments with a core radius) or a convex
/// polygon, with a quadratic falloff outside the core.
class _Part {
  _Part(
    this.group, {
    this.segments = const [],
    this.polygon = const [],
    required this.core,
    required this.falloff,
    this.bias = 0,
  });
  final String group;
  final List<(math.Point<double>, math.Point<double>)> segments;
  final List<math.Point<double>> polygon;
  final double core, falloff;

  /// Constant cost so this part only wins where nothing else fits.
  final double bias;

  double cost(double x, double y) {
    final p = math.Point(x, y);
    var distance = double.infinity;
    for (final (a, b) in segments) {
      distance = math.min(distance, _segmentDistance(p, a, b));
    }
    if (polygon.isNotEmpty) {
      distance = math.min(distance, _polygonDistance(p, polygon));
    }
    final outside = math.max(0.0, distance - core) / falloff;
    return bias + outside * outside;
  }

  static List<_Part> build(_Pose pose, double shoulder, int height) {
    // Nearer parts come first: on equal cost the earlier part wins, and the
    // torso is the fallback for everything else.
    final hands = <_Part>[],
        arms = <_Part>[],
        legs = <_Part>[],
        head = <_Part>[],
        torso = <_Part>[];

    final facePoints = [0, 2, 5, 7, 8, 9, 10].where(pose.visible).toList();
    if (facePoints.contains(0) || (pose.visible(7) && pose.visible(8))) {
      var cx = 0.0, cy = 0.0;
      for (final i in facePoints) {
        cx += pose.at(i).x;
        cy += pose.at(i).y;
      }
      final center = math.Point(cx / facePoints.length, cy / facePoints.length);
      var radius = shoulder * _K.headRadius;
      if (pose.visible(7) && pose.visible(8)) {
        radius = math.max(radius, pose.distance(7, 8) * _K.headRadiusFromEars);
      }
      final crown = math.Point(center.x, center.y - radius * _K.hairLift);
      head.add(
        _Part(
          'head',
          segments: [(center, crown)],
          core: radius * _K.headCore,
          falloff: radius * _K.headFalloff,
        ),
      );
    }

    if (pose.visible(11) && pose.visible(12)) {
      final l = pose.at(11), r = pose.at(12);
      final polygon = pose.visible(23) && pose.visible(24)
          ? [l, r, pose.at(24), pose.at(23)]
          : [
              l,
              r,
              math.Point(r.x, r.y + shoulder * _K.torsoLength),
              math.Point(l.x, l.y + shoulder * _K.torsoLength),
            ];
      torso.add(
        _Part(
          'torso',
          polygon: polygon,
          core: 0,
          falloff: shoulder * _K.torsoFalloff,
          bias: _K.torsoBias,
        ),
      );
    }

    for (final (shoulderIndex, elbow, wrist) in [(11, 13, 15), (12, 14, 16)]) {
      final segments = <(math.Point<double>, math.Point<double>)>[];
      if (pose.visible(shoulderIndex) && pose.visible(elbow)) {
        segments.add((pose.at(shoulderIndex), pose.at(elbow)));
      }
      if (pose.visible(elbow) && pose.visible(wrist)) {
        // Stop short of the wrist so the hand keeps the pixels around it.
        final e = pose.at(elbow), w = pose.at(wrist);
        segments.add((
          e,
          math.Point(
            e.x + (w.x - e.x) * _K.forearmReach,
            e.y + (w.y - e.y) * _K.forearmReach,
          ),
        ));
      }
      if (segments.isNotEmpty) {
        arms.add(
          _Part(
            'arms',
            segments: segments,
            core: shoulder * _K.armCore,
            falloff: shoulder * _K.armFalloff,
          ),
        );
      }
    }

    for (final (wrist, tips) in [
      (15, [17, 19, 21]),
      (16, [18, 20, 22]),
    ]) {
      if (!pose.visible(wrist)) continue;
      final segments = [
        for (final tip in tips.where(pose.visible))
          (pose.at(wrist), pose.at(tip)),
      ];
      if (segments.isEmpty) segments.add((pose.at(wrist), pose.at(wrist)));
      hands.add(
        _Part(
          'hands',
          segments: segments,
          core: shoulder * _K.handCore,
          falloff: shoulder * _K.handFalloff,
        ),
      );
    }
    for (final (hip, knee, ankle) in [(23, 25, 27), (24, 26, 28)]) {
      final segments = <(math.Point<double>, math.Point<double>)>[];
      if (pose.visible(hip) && pose.visible(knee)) {
        segments.add((pose.at(hip), pose.at(knee)));
      }
      if (pose.visible(knee) && pose.visible(ankle)) {
        segments.add((pose.at(knee), pose.at(ankle)));
      }
      if (segments.isNotEmpty) {
        legs.add(
          _Part(
            'legs',
            segments: segments,
            core: shoulder * _K.legCore,
            falloff: shoulder * _K.legFalloff,
          ),
        );
      }
    }
    return [...hands, ...arms, ...legs, ...head, ...torso];
  }
}

double _segmentDistance(
  math.Point<double> p,
  math.Point<double> a,
  math.Point<double> b,
) {
  final ab = b - a;
  final length2 = ab.x * ab.x + ab.y * ab.y;
  if (length2 == 0) return p.distanceTo(a);
  final t = (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / length2).clamp(
    0.0,
    1.0,
  );
  return p.distanceTo(math.Point(a.x + ab.x * t, a.y + ab.y * t));
}

/// Zero inside a convex polygon, else the distance to its nearest edge.
double _polygonDistance(
  math.Point<double> p,
  List<math.Point<double>> polygon,
) {
  var positive = false, negative = false;
  var distance = double.infinity;
  for (var i = 0; i < polygon.length; i++) {
    final a = polygon[i], b = polygon[(i + 1) % polygon.length];
    final cross = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);
    if (cross > 0) positive = true;
    if (cross < 0) negative = true;
    distance = math.min(distance, _segmentDistance(p, a, b));
  }
  return positive && negative ? distance : 0;
}

class _Layer {
  _Layer(this.group, this.depth, this.share);
  final String group;
  final double depth, share;

  static List<_Layer> collect(
    List<String> groups,
    List<_Part> parts,
    Int8List labels,
    _Grid grid,
  ) {
    final histograms = {for (final g in groups) g: Uint32List(256)};
    var inside = 0;
    for (var i = 0; i < grid.count; i++) {
      final label = labels[i];
      if (label < 0) continue;
      inside++;
      histograms[parts[label].group]![grid.depth[i]]++;
    }
    return [
      for (final group in groups)
        if (histograms[group]!.fold<int>(0, (a, b) => a + b) case final total
            when total > 0)
          _Layer(
            group,
            _median(histograms[group]!, total).toDouble(),
            inside == 0 ? 0 : total / inside,
          ),
    ];
  }
}
