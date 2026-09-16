import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/person_layering.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';
import 'package:timo/features/memory/widgets/ui/person_depth_options.dart';

/// A synthetic person: round head, rectangular torso and a hand held in
/// front of the chest, each at its own depth (0 = far, 255 = near).
class _Figure {
  static const width = 200, height = 300;
  static const head = (x: 100.0, y: 50.0, r: 30.0, depth: 150);
  static const torso = (left: 50, top: 80, right: 150, bottom: 260, depth: 100);
  static const hand = (x: 100.0, y: 170.0, r: 22.0, depth: 230);

  static bool inHead(int x, int y) =>
      math.Point(x + 0.5, y + 0.5).distanceTo(math.Point(head.x, head.y)) <
      head.r;
  static bool inHand(int x, int y) =>
      math.Point(x + 0.5, y + 0.5).distanceTo(math.Point(hand.x, hand.y)) <
      hand.r;
  static bool inTorso(int x, int y) =>
      x >= torso.left && x < torso.right && y >= torso.top && y < torso.bottom;

  static PartMapInput input({List<Landmark>? landmarks}) {
    final alpha = Uint8List(width * height);
    final depth = Uint8List(width * height)..fillRange(0, width * height, 128);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        if (inHand(x, y)) {
          alpha[i] = 255;
          depth[i] = hand.depth;
        } else if (inHead(x, y)) {
          alpha[i] = 255;
          depth[i] = head.depth;
        } else if (inTorso(x, y)) {
          alpha[i] = 255;
          depth[i] = torso.depth;
        }
      }
    }
    return PartMapInput(
      width: width,
      height: height,
      alpha: alpha,
      depth: depth,
      landmarks: landmarks ?? pose(),
    );
  }

  /// MediaPipe indices, normalised to the figure. Legs and the right hand are
  /// out of frame.
  static List<Landmark> pose({double shoulderVisibility = 1}) {
    final points = List<Landmark>.filled(33, const Landmark(0, 0, 0));
    Landmark at(double x, double y, [double v = 1]) =>
        Landmark(x / width, y / height, v);
    points[0] = at(100, 50);
    points[2] = at(92, 45);
    points[5] = at(108, 45);
    points[7] = at(80, 50);
    points[8] = at(120, 50);
    points[9] = at(96, 60);
    points[10] = at(104, 60);
    points[11] = at(55, 90, shoulderVisibility);
    points[12] = at(145, 90, shoulderVisibility);
    points[13] = at(40, 150, 0.9);
    points[14] = at(160, 150, 0.9);
    points[15] = at(100, 171);
    points[17] = at(90, 182);
    points[19] = at(100, 186);
    points[21] = at(110, 182);
    points[23] = at(60, 255);
    points[24] = at(140, 255);
    return points;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('landmarks parse only from a complete pose list', () {
    expect(Landmark.parse(null), isNull);
    expect(
      Landmark.parse([
        for (var i = 0; i < 10; i++) {'x': 0, 'y': 0, 'v': 1},
      ]),
      isNull,
    );
    final parsed = Landmark.parse([
      for (var i = 0; i < 33; i++) {'x': i / 33, 'y': 0.5, 'v': 0.9},
    ]);
    expect(parsed, hasLength(33));
    expect(parsed![32].x, closeTo(32 / 33, 1e-9));
  });

  test(
    'head, torso and a hand in front split into layers ordered far to near',
    () {
      final result = computePartMap(_Figure.input());
      expect(result, isNotNull);
      final layers = result!.layers;
      expect(
        layers.map((l) => l.label),
        containsAll(['torso', 'head', 'hands']),
      );
      expect(layers.map((l) => l.label), isNot(contains('arms')));
      for (var i = 1; i < layers.length; i++) {
        expect(layers[i].depth, greaterThanOrEqualTo(layers[i - 1].depth));
      }
      expect(layers.first.label, 'torso');
      expect(layers.last.label, 'hands');
      expect(layers.first.share, greaterThan(0.5));
      expect(layers.last.depth, closeTo(_Figure.hand.depth / 255, 0.02));

      // The map keeps the figure's resolution (long side under the limit).
      expect((result.width, result.height), (_Figure.width, _Figure.height));
      int channel(int x, int y, int c) =>
          result.rgba[(y * result.width + x) * 4 + c];
      // Torso is layer 0 (R), head layer 1 (G), hands the remainder.
      expect(channel(70, 240, 0), greaterThan(240));
      expect(channel(70, 240, 1), lessThan(10));
      expect(channel(100, 40, 1), greaterThan(240));
      expect(channel(100, 40, 0), lessThan(10));
      expect(channel(100, 170, 0) + channel(100, 170, 1), lessThan(10));
      // The hand/torso boundary is feathered rather than a hard step.
      final edge = channel(100, 170 + _Figure.hand.r.toInt(), 0);
      expect(edge, inInclusiveRange(20, 235));
      // Alpha stays opaque so the weights survive premultiplication.
      for (var i = 3; i < result.rgba.length; i += 4) {
        expect(result.rgba[i], 255);
      }
      // Weights are pushed past the outline instead of fading to zero.
      expect(channel(48, 240, 0) + channel(48, 240, 1), greaterThan(200));
    },
  );

  test('no split without a usable pose or with a single part', () {
    expect(
      computePartMap(
        _Figure.input(landmarks: List.filled(33, const Landmark(0, 0, 0))),
      ),
      isNull,
    );
    final headOnly = List<Landmark>.filled(33, const Landmark(0, 0, 0));
    headOnly[0] = const Landmark(0.5, 0.17, 1);
    expect(computePartMap(_Figure.input(landmarks: headOnly)), isNull);
  });

  test('layer json round-trips and gates the layered shader', () {
    final layer = PersonDepthLayer.fromJson({
      'path': 'p.png',
      'depthMapPath': 'd.png',
      'partMapPath': 'parts.png',
      'parts': [
        {'label': 'torso', 'depth': 0.4, 'share': 0.7},
        {'label': 'hands', 'depth': 0.9, 'share': 0.1},
      ],
      'layered': true,
      'strength': 'strong',
      'placement': {'left': 0.1, 'top': 0.2, 'width': 0.5, 'height': 0.6},
    });
    expect(layer.usesPartLayers, true);
    expect(layer.parts.map((p) => p.name), ['몸통', '손']);
    final copy = PersonDepthLayer.fromJson(layer.toJson());
    expect(copy.partMapPath, 'parts.png');
    expect(copy.parts.length, 2);
    expect(copy.withStrength(PersonDepthStrength.weak).layered, true);
    // Legacy tickets and switched-off splits fall back to the single map.
    expect(
      PersonDepthLayer.fromJson(
        layer.toJson()
          ..remove('parts')
          ..remove('layered'),
      ).usesPartLayers,
      false,
    );
    expect(
      PersonDepthLayer.fromJson(layer.toJson()..['layered'] = false)
          .usesPartLayers,
      false,
    );
  });

  testWidgets(
    'the split toggle appears only with layers and follows strength',
    (tester) async {
      var layered = true;
      var strength = PersonDepthStrength.weak;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PersonDepthOptions(
                value: strength,
                onChanged: (v) => setState(() => strength = v),
                layerLabels: const ['몸통', '머리', '손'],
                layered: layered,
                onLayeredChanged: (v) => setState(() => layered = v),
              ),
            ),
          ),
        ),
      );
      final toggle = find.byKey(const ValueKey('person-depth-layered'));
      expect(toggle, findsOneWidget);
      expect(find.textContaining('층 3개'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pump();
      expect(layered, false);
      await tester.tap(find.byKey(const ValueKey('person-depth-off')));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonDepthOptions(value: strength, onChanged: (_) {}),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('person-depth-layered')), findsNothing);
    },
  );

  test(
    'layered shader keeps alpha and rest pose while layers slide apart',
    () async {
      const size = 128;
      // Opaque disc whose red channel encodes x, so displacement reads as Δred.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.clipPath(Path()..addOval(const Rect.fromLTWH(8, 8, 112, 112)));
      for (var x = 0; x < size; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x.toDouble(), 0, 1, size.toDouble()),
          Paint()..color = Color.fromARGB(255, x * 2, 40, 40),
        );
      }
      final picture = recorder.endRecording();
      final photo = await picture.toImage(size, size);
      picture.dispose();

      Future<ui.Image> flat(Color left, Color right) async {
        final r = ui.PictureRecorder();
        Canvas(r)
          ..drawRect(const Rect.fromLTWH(0, 0, 64, 128), Paint()..color = left)
          ..drawRect(
            const Rect.fromLTWH(64, 0, 64, 128),
            Paint()..color = right,
          );
        final p = r.endRecording();
        final image = await p.toImage(size, size);
        p.dispose();
        return image;
      }

      // Left half = layer 0 (far, 0.2), right half = nearest layer (0.9).
      const far = 0.2, near = 0.9;
      final depth = await flat(
        Color.fromARGB(255, (far * 255).round(), 0, 0),
        Color.fromARGB(255, (near * 255).round(), 0, 0),
      );
      final parts = await flat(
        const Color(0xFFFF0000),
        const Color(0xFF000000),
      );
      final shader = (await ui.FragmentProgram.fromAsset(
        'shaders/person_layers.frag',
      )).fragmentShader();
      final layers = const [
        PersonPart(label: 'torso', depth: far, share: 0.5),
        PersonPart(label: 'hands', depth: near, share: 0.5),
      ];
      Future<ByteData> render(double tilt, PersonDepthStrength strength) async {
        shader
          ..setFloat(0, size.toDouble())
          ..setFloat(1, size.toDouble())
          ..setFloat(2, tilt)
          ..setFloat(3, 0)
          ..setFloat(4, strength.displacement)
          ..setFloat(5, ViewerConstants.personLayerGain)
          ..setFloat(6, ViewerConstants.personReliefGain)
          ..setFloat(7, layers.length.toDouble())
          ..setFloat(8, layers[0].depth)
          ..setFloat(9, layers[1].depth)
          ..setFloat(10, 0.5)
          ..setFloat(11, 0.5)
          ..setImageSampler(0, photo)
          ..setImageSampler(1, depth)
          ..setImageSampler(2, parts);
        final r = ui.PictureRecorder();
        Canvas(r).drawRect(
          const Rect.fromLTWH(0, 0, 128, 128),
          Paint()..shader = shader,
        );
        final p = r.endRecording();
        final image = await p.toImage(size, size);
        p.dispose();
        final data = (await image.toByteData())!;
        image.dispose();
        return data;
      }

      final original = (await photo.toByteData())!;
      final rest = await render(0, PersonDepthStrength.strong);
      final strong = await render(1, PersonDepthStrength.strong);
      var leftShift = 0.0, rightShift = 0.0;
      var leftCount = 0, rightCount = 0;
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final i = (y * size + x) * 4;
          expect(strong.getUint8(i + 3), original.getUint8(i + 3));
          expect(rest.getUint8(i), closeTo(original.getUint8(i), 1));
          // Deep inside each half, away from the outline and the seam.
          if ((y - 64).abs() > 20) continue;
          final delta = (strong.getUint8(i) - original.getUint8(i)) / 2;
          if (x >= 36 && x < 52) {
            leftShift += delta;
            leftCount++;
          } else if (x >= 76 && x < 92) {
            rightShift += delta;
            rightCount++;
          }
        }
      }
      leftShift /= leftCount;
      rightShift /= rightCount;
      // Far layer slides one way, the near layer the other and further.
      expect(leftShift, greaterThan(0.5));
      expect(rightShift, lessThan(-0.5));
      expect(rightShift.abs(), greaterThan(leftShift.abs()));
      shader.dispose();
      photo.dispose();
      depth.dispose();
      parts.dispose();
    },
  );
}
