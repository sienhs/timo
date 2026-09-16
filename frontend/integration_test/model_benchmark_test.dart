import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// On-device measurement driver for tools/benchmark_models.py.
//
// Input (staged by `python tools/benchmark_models.py push`) under the app support
// dir: bench/config.json, bench/seg/*.jpg, bench/depth/*, bench/models/*.onnx.
// Output: bench/out/{seg,depth}/... plus segment_results.json / depth_results.json.
// Nothing is uploaded; run with --no-uninstall so app data survives.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('timo/image_pipeline');

  Future<Map<String, dynamic>> call(
    String method,
    Map<String, dynamic> args,
  ) async => Map<String, dynamic>.from(
    (await channel.invokeMapMethod<String, dynamic>(method, args))!,
  );

  List<File> listed(Directory dir) {
    if (!dir.existsSync()) return const [];
    return dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  String stem(File f) {
    final name = f.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }

  testWidgets('segmentation and depth model benchmark on device', (
    tester,
  ) async {
    final root = Directory(
      '${(await getApplicationSupportDirectory()).path}/bench',
    );
    if (!root.existsSync()) {
      // Measurement driver, not a regression: skip when no inputs are staged
      // so running the whole integration_test folder stays green.
      markTestSkipped('no staged inputs; run tools/benchmark_models.py push');
      return;
    }
    final config =
        jsonDecode(File('${root.path}/config.json').readAsStringSync()) as Map;
    final engines = List<String>.from(
      config['segEngines'] as List? ?? ['modnet', 'mlkit', 'mlkit_raw'],
    );
    final depthRuns = (config['depthRuns'] as num?)?.toInt() ?? 3;
    final out = Directory('${root.path}/out')..createSync(recursive: true);

    Future<Map<String, dynamic>> segment(
      File image,
      String engine,
      String target,
    ) => call('benchmarkSegment', {
      'path': image.path,
      'engine': engine,
      'out': target,
    });

    // --- Segmentation -----------------------------------------------------
    final segImages = listed(Directory('${root.path}/seg'));
    final segResults = <Map<String, dynamic>>[];
    // Warm-up on the first image so cold-start costs are recorded separately.
    for (final engine in engines) {
      if (segImages.isEmpty) break;
      try {
        final r = await segment(
          segImages.first,
          engine,
          '${out.path}/seg/_warmup_$engine.png',
        );
        segResults.add({...r, 'image': stem(segImages.first), 'warmup': true});
      } catch (e) {
        segResults.add({
          'engine': engine,
          'image': stem(segImages.first),
          'warmup': true,
          'error': '$e',
        });
      }
    }
    var index = 0;
    for (final image in segImages) {
      index++;
      for (final engine in engines) {
        try {
          final r = await segment(
            image,
            engine,
            '${out.path}/seg/${stem(image)}_$engine.png',
          );
          segResults.add({...r, 'image': stem(image), 'warmup': false});
        } catch (e) {
          segResults.add({
            'engine': engine,
            'image': stem(image),
            'warmup': false,
            'error': '$e',
          });
        }
      }
      if (index % 10 == 0) {
        // ignore: avoid_print
        print('benchmark segment $index/${segImages.length}');
        File('${out.path}/segment_results.json')
            .writeAsStringSync(jsonEncode(segResults));
      }
    }
    File('${out.path}/segment_results.json')
        .writeAsStringSync(jsonEncode(segResults));

    // --- Depth --------------------------------------------------------------
    final depthImages = listed(Directory('${root.path}/depth'));
    final models = <String, String?>{'int8': null};
    for (final m in listed(Directory('${root.path}/models'))) {
      if (m.path.endsWith('.onnx')) models[stem(m)] = m.path;
    }
    final depthResults = <Map<String, dynamic>>[];
    index = 0;
    for (final image in depthImages) {
      index++;
      for (final entry in models.entries) {
        try {
          final r = await call('benchmarkDepth', {
            'path': image.path,
            'model': entry.value,
            'runs': depthRuns,
            'out': '${out.path}/depth/${stem(image)}_${entry.key}.f32',
          });
          depthResults.add({...r, 'tag': entry.key, 'image': stem(image)});
        } catch (e) {
          depthResults.add({
            'tag': entry.key,
            'image': stem(image),
            'error': '$e',
          });
        }
      }
      // ignore: avoid_print
      print('benchmark depth $index/${depthImages.length}');
      File('${out.path}/depth_results.json')
          .writeAsStringSync(jsonEncode(depthResults));
    }
    File('${out.path}/depth_results.json')
        .writeAsStringSync(jsonEncode(depthResults));
    File('${out.path}/done.json').writeAsStringSync(
      jsonEncode({
        'segImages': segImages.length,
        'depthImages': depthImages.length,
        'engines': engines,
        'models': models.keys.toList(),
        'finished': DateTime.now().toIso8601String(),
      }),
    );
    expect(
      segResults.where((r) => r['error'] == null).isNotEmpty ||
          segImages.isEmpty,
      true,
    );
  }, timeout: const Timeout(Duration(minutes: 60)));
}
