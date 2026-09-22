import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/memory_concert.dart';
import 'depth_service.dart';
import 'image_download.dart';
import 'person_layering.dart';
import 'composition_service.dart';
import 'segmentation_service.dart';
import '../models/memory_ticket.dart';
import '../models/photo_framing.dart';
import '../models/person_depth_layer.dart';

class CreationService {
  final segmentation = SegmentationService();
  final composition = CompositionService();
  final depth = DepthService();
  final layering = PersonLayering();
  static const _channel = MethodChannel('timo/image_pipeline');

  /// 고른 사진을 앱 전용 폴더로 가져온다. 파이프라인은 이 경로만 읽는다.
  ///
  /// 출처가 셋이다 — 갤러리·카메라가 준 기기 파일(기본), 앱 에셋([asset]),
  /// 서버 소재 주소([remote]). 어디서 왔든 결과는 같은 폴더의 파일 하나라
  /// 그 뒤 단계는 출처를 모른다.
  Future<String> copyPhotoToPrivateStorage(
    String source, {
    bool asset = false,
    bool remote = false,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory('${root.path}/photos');
    await folder.create(recursive: true);
    final extension = remote ? imageExtension(source) : source.split('.').last;
    final target = File(
      '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    if (remote) {
      await downloadImage(source, target.path);
    } else if (asset) {
      final data = await rootBundle.load(source);
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } else {
      await File(source).copy(target.path);
    }
    return target.path;
  }

  Future<Map<String, dynamic>> segmentAndAnalyze(String path) async {
    final result = await segmentation.removeBackground(path);
    final person = await _preparePerson(
      path,
      result['path'] as String,
      result['crop'] == null
          ? null
          : Map<String, dynamic>.from(result['crop'] as Map),
      segmented: true,
    );
    person['segmentationEngine'] = result['engine'] ?? 'mlkit';
    return person;
  }

  Future<Map<String, dynamic>> analyzeOriginalForDemo(String path) =>
      _preparePerson(path, path, {
        'left': 0.0,
        'top': 0.0,
        'width': 1.0,
        'height': 1.0,
      }, segmented: false);

  /// Segmentation and analysis only. Nobody is cropped here: a single person
  /// keeps the whole cutout, and two people are matched by [harmonizeCrops].
  Future<Map<String, dynamic>> _preparePerson(
    String source,
    String output,
    Map<String, dynamic>? crop, {
    required bool segmented,
  }) async {
    final analysis = await composition.analyze(output);
    final personDepth = await _analyzeDepth(
      source: source,
      cutout: output,
      crop: crop,
      analysis: analysis,
    );
    return {
      'path': output,
      'analysis': analysis,
      'segmented': segmented,
      'sourcePath': source,
      'sourceCrop': crop,
      'upperBodyCropped': false,
      'originalCropType': analysis['cropType'],
      ...personDepth,
      'full': {
        'path': output,
        'analysis': analysis,
        'sourceCrop': crop,
        ...personDepth,
      },
      'depthStrength': PersonDepthStrength.weak.name,
      // Body-part layers are on whenever the split succeeded.
      'layeredDepth': personDepth['partMapPath'] != null,
      'scale': 1.0,
      'dx': 0.0,
      'dy': 0.0,
    };
  }

  /// The aligned depth map plus the optional body-part split for one cutout.
  /// Keys: personDepthPath, partMapPath, parts (far to near).
  Future<Map<String, dynamic>> _analyzeDepth({
    required String source,
    required String cutout,
    required Map<String, dynamic>? crop,
    required Map<String, dynamic> analysis,
  }) async {
    final depthMap = crop == null
        ? null
        : await depth.analyzePerson(source: source, cutout: cutout, crop: crop);
    final split = depthMap == null
        ? null
        : await layering.build(
            cutoutPath: cutout,
            depthMapPath: depthMap,
            analysis: analysis,
          );
    return {
      'personDepthPath': depthMap,
      'partMapPath': split?.partMapPath,
      'parts': [for (final part in split?.layers ?? const []) part.toJson()],
    };
  }

  /// Bring two people to the same skeletal framing. The person whose cutout
  /// ends higher on the body (e.g. an upper-body photo) is the reference; the
  /// other is cut at the same point along their own shoulder-to-hip axis.
  /// A single person, two full bodies, or a manually repaired mask stay intact.
  /// Returns the indices whose image changed so placements can be re-seeded.
  Future<List<int>> harmonizeCrops(List<Map<String, dynamic>> people) async {
    final changed = <int>[];
    for (var i = 0; i < people.length; i++) {
      if (_restoreFull(people[i])) changed.add(i);
    }
    if (people.length != 2) return changed;
    final cutoffs = [
      matchedCutoff(
        reference: people[1]['analysis'] as Map<String, dynamic>,
        target: people[0]['analysis'] as Map<String, dynamic>,
      ),
      matchedCutoff(
        reference: people[0]['analysis'] as Map<String, dynamic>,
        target: people[1]['analysis'] as Map<String, dynamic>,
      ),
    ];
    for (var i = 0; i < people.length; i++) {
      final cutoff = cutoffs[i];
      final person = people[i];
      if (cutoff == null || person['manuallyRepaired'] == true) continue;
      final full = person['full'] as Map<String, dynamic>;
      final upper = await segmentation.cropUpperBody(
        full['path'] as String,
        cutoff,
      );
      final path = upper['path'] as String;
      final fullCrop = full['sourceCrop'] as Map<String, dynamic>?;
      final crop = fullCrop == null
          ? null
          : combineCrops(
              fullCrop,
              Map<String, dynamic>.from(upper['crop'] as Map),
            );
      final analysis = await composition.analyze(path);
      person
        ..['path'] = path
        ..['analysis'] = analysis
        ..['sourceCrop'] = crop
        ..addAll(
          await _analyzeDepth(
            source: person['sourcePath'] as String,
            cutout: path,
            crop: crop,
            analysis: analysis,
          ),
        )
        ..['upperBodyCropped'] = true;
      if (!changed.contains(i)) changed.add(i);
    }
    return changed;
  }

  /// Put the untouched cutout back. True when the image actually changed.
  static bool _restoreFull(Map<String, dynamic> person) {
    final full = person['full'] as Map<String, dynamic>?;
    if (full == null || person['manuallyRepaired'] == true) return false;
    final changed = person['path'] != full['path'];
    person
      ..['path'] = full['path']
      ..['analysis'] = full['analysis']
      ..['sourceCrop'] = full['sourceCrop']
      ..['personDepthPath'] = full['personDepthPath']
      ..['partMapPath'] = full['partMapPath']
      ..['parts'] = full['parts'] ?? const []
      ..['upperBodyCropped'] = false;
    return changed;
  }

  /// How far below the shoulders a cutout ends, in torso lengths
  /// (0 = shoulder line, 1 = hips, >1 = below the hips). Null without shoulders
  /// or any cue for torso length.
  static double? bottomInTorso(Map<String, dynamic> analysis) {
    final shoulderY = ((analysis['shoulderCenter'] as Map?)?['y'] as num?)
        ?.toDouble();
    final torso = torsoLength(analysis);
    if (shoulderY == null || torso == null || !shoulderY.isFinite) return null;
    if (shoulderY < 0 || shoulderY > 1) return null;
    return (1 - shoulderY) / torso;
  }

  /// Shoulder-to-hip distance as a fraction of image height. Measured when
  /// hips are visible, otherwise estimated with the same anthropometric ratios
  /// the composer uses (body ≈ 3.3 torsos ≈ 7.5 faces ≈ 4.0 shoulder widths).
  static double? torsoLength(Map<String, dynamic> analysis) {
    final measured = (analysis['torsoLength'] as num?)?.toDouble();
    if (measured != null && measured.isFinite && measured > 0.02) {
      return measured;
    }
    final face = (analysis['faceHeight'] as num?)?.toDouble();
    if (face != null && face.isFinite && face > 0.01) return face * 7.5 / 3.3;
    final shoulder = (analysis['shoulderWidth'] as num?)?.toDouble();
    final width = (analysis['width'] as num?)?.toDouble();
    final height = (analysis['height'] as num?)?.toDouble();
    if (shoulder != null &&
        shoulder.isFinite &&
        shoulder > 0.02 &&
        width != null &&
        height != null &&
        height > 0) {
      return shoulder * width / height * 4.0 / 3.3;
    }
    return null;
  }

  /// Where to cut [target] so it ends at the same skeletal point as
  /// [reference]. Null when the reference already reaches lower than the
  /// target, when either pose is unusable, or when the cut would be a no-op.
  static double? matchedCutoff({
    required Map<String, dynamic> reference,
    required Map<String, dynamic> target,
  }) {
    final refBottom = bottomInTorso(reference);
    final targetBottom = bottomInTorso(target);
    if (refBottom == null || targetBottom == null) return null;
    if (refBottom >= targetBottom - 0.05) return null;
    final shoulderY = ((target['shoulderCenter'] as Map)['y'] as num)
        .toDouble();
    var bottom = shoulderY + refBottom * torsoLength(target)!;
    // Fingertips just under the line look severed; forearms cut higher up
    // read as an ordinary portrait crop, so only nudge for the near case.
    final handBottom = (target['handBottom'] as num?)?.toDouble();
    if (handBottom != null &&
        handBottom.isFinite &&
        handBottom >= bottom &&
        handBottom < bottom + 0.06) {
      bottom = handBottom + 0.045;
    }
    if (bottom >= 0.97) return null;
    return bottom.clamp(0.3, 0.97);
  }

  static Map<String, dynamic> combineCrops(
    Map<String, dynamic> outer,
    Map<String, dynamic> inner,
  ) => {
    'left':
        (outer['left'] as num) +
        (inner['left'] as num) * (outer['width'] as num),
    'top':
        (outer['top'] as num) +
        (inner['top'] as num) * (outer['height'] as num),
    'width': (outer['width'] as num) * (inner['width'] as num),
    'height': (outer['height'] as num) * (inner['height'] as num),
  };

  /// A manual mask is already framed by the user; do not auto-crop it again.
  Future<Map<String, dynamic>> repairPerson(
    Map<String, dynamic> person,
    String repairedFullSource,
  ) async {
    final trimmed = await segmentation.cropUpperBody(repairedFullSource, 1.0);
    final path = trimmed['path'] as String;
    final crop = Map<String, dynamic>.from(trimmed['crop'] as Map);
    final oldCrop = person['sourceCrop'] as Map;
    Map<String, double> align(Map old) {
      final width = (old['width'] as num) / (oldCrop['width'] as num);
      final height = (old['height'] as num) / (oldCrop['height'] as num);
      return {
        'left':
            (old['left'] as num) +
            ((crop['left'] as num) - (oldCrop['left'] as num)) * width,
        'top':
            (old['top'] as num) +
            ((crop['top'] as num) - (oldCrop['top'] as num)) * height,
        'width': (crop['width'] as num) * width,
        'height': (crop['height'] as num) * height,
      };
    }

    final analysis = await composition.analyze(path);
    return {
      ...person,
      'path': path,
      'sourceCrop': crop,
      'analysis': analysis,
      ...await _analyzeDepth(
        source: person['sourcePath'] as String,
        cutout: path,
        crop: crop,
        analysis: analysis,
      ),
      'placement': align(person['placement'] as Map),
      'initialPlacement': align(person['initialPlacement'] as Map),
      'manuallyRepaired': true,
    };
  }

  /// Render the chosen crop or matte locally before depth analysis.
  Future<({Map<String, dynamic> depth, List<String> notes})> prepareBackground(
    String source, {
    PhotoFraming framing = const PhotoFraming(),
  }) async {
    final input = await renderBackground(source, framing: framing);
    final result = await depth.analyzeAndCache(input);
    return (
      depth: result,
      notes: [framing.contain ? '배경: 전체 사진과 단색 여백' : '배경: 티켓 비율에 맞춘 사진 자르기'],
    );
  }

  Future<String> renderBackground(
    String source, {
    PhotoFraming framing = const PhotoFraming(),
  }) async {
    final codec = await ui.instantiateImageCodec(
      await File(source).readAsBytes(),
    );
    late final ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    try {
      const width = 900, height = 1400;
      final recorder = ui.PictureRecorder();
      framing.paint(ui.Canvas(recorder), image, const ui.Size(900, 1400));
      final picture = recorder.endRecording();
      late final ui.Image rendered;
      try {
        rendered = await picture.toImage(width, height);
      } finally {
        picture.dispose();
      }
      try {
        final bytes = (await rendered.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        final root = await getApplicationDocumentsDirectory();
        final folder = await Directory('${root.path}/framed_backgrounds')
            .create(recursive: true);
        final file = File(
          '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        return file.path;
      } finally {
        rendered.dispose();
      }
    } finally {
      image.dispose();
    }
  }

  Future<MemoryTicket> generateTicket({
    required MemoryConcert concert,
    required String background,
    required List<Map<String, dynamic>> people,
    required String effect,
    PhotoFraming framing = const PhotoFraming(),
  }) async {
    final composite = await composition.compose(people);
    final prepared = await prepareBackground(background, framing: framing);
    final depthResult = prepared.depth;
    Map<String, dynamic> transition;
    try {
      transition = Map<String, dynamic>.from(
        (await _channel.invokeMapMethod<String, dynamic>('transition', {
          'path': depthResult['backgroundPath'],
          'video': concert.videoUrl,
        }))!,
      );
    } catch (_) {
      transition = {'firstFrameAnalyzed': false};
    }
    final notes = <String>[...prepared.notes];
    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      final a = p['analysis'] as Map;
      notes.add(
        '인물 ${i + 1}: ${engineLabel(p)} · ${a['poseAvailable'] == true ? cropLabel(a['cropType'] as String) : '자세 분석 실패 · 크기 기반 배치'} · ${a['faceAvailable'] == true ? '얼굴 분석 완료' : '얼굴 크기 추정 배치'}',
      );
      if (p['upperBodyCropped'] == true) {
        notes.add('인물 ${i + 1}: 상대 인물 골격에 맞춰 자동 자르기');
      }
      notes.add(
        p['personDepthPath'] == null
            ? '인물 ${i + 1} 입체감: 깊이 분석 불가 · 고정 이미지'
            : '인물 ${i + 1} 깊이: 원본 사진에서 실제 추정',
      );
      if (p['personDepthPath'] != null) notes.add(layerNote(i + 1, p));
    }
    return MemoryTicket(
      // 티켓 번호가 곧 소장품의 번호다. 한 티켓으로 다시 만들면 예전 것을
      // 덮어쓴다 — 서버의 1티켓 1소장품과 같은 규칙이다.
      ticketId: concert.ticketId,
      concertId: concert.id,
      backgroundPath: depthResult['backgroundPath'] as String,
      sourceBackgroundPath: background,
      backgroundFraming: framing,
      personCompositePath: composite,
      manualPersonLayout: people.every((p) => p['placement'] != null),
      personDepthLayers: people.every((p) => p['placement'] != null)
          ? [
              for (final p in people)
                PersonDepthLayer.fromJson({
                  'path': p['path'],
                  'depthMapPath': p['personDepthPath'],
                  'partMapPath': p['partMapPath'],
                  'parts': p['parts'],
                  'layered': p['layeredDepth'] == true,
                  'placement': p['placement'],
                  'order': p['order'],
                  'strength': p['depthStrength'],
                }),
            ]
          : const [],
      effectType: effect,
      videoId: concert.videoId,
      videoUrl: concert.videoUrl,
      details: concert.ticketDetails,
      depthLayers: List<String>.from(depthResult['layers'] as List),
      depthMapPath: depthResult['depthMapPath'] as String,
      demoDepth: depthResult['demo'] as bool,
      processingNotes: notes,
      transition: transition,
    );
  }

  /// Reopening a saved ticket preserves its framing and never calls AI.
  Future<MemoryTicket> upgradeBackground(MemoryTicket ticket) =>
      _upgradeDemoDepth(ticket);

  /// Replace legacy demo depth using the already prepared background. This
  /// path never rebuilds the person composition.
  Future<MemoryTicket> _upgradeDemoDepth(MemoryTicket ticket) async {
    if (!ticket.demoDepth) return ticket;
    final result = await depth.analyzeAndCache(ticket.backgroundPath);
    if (result['demo'] == true) return ticket;
    return ticket.copyWith(
      backgroundPath: result['backgroundPath'] as String,
      depthLayers: List<String>.from(result['layers'] as List),
      depthMapPath: result['depthMapPath'] as String,
      demoDepth: false,
    );
  }

  /// Processing note for the body-part split of one person.
  static String layerNote(int index, Map<String, dynamic> person) {
    final parts = [
      for (final part in person['parts'] as List? ?? const [])
        PersonPart.fromJson(Map<String, dynamic>.from(part as Map)),
    ];
    if (parts.length < 2) return '인물 $index 층: 자세 기반 분리 불가 · 단일 깊이';
    final names = parts.map((p) => p.name).join('·');
    return person['layeredDepth'] == true
        ? '인물 $index 층: ${parts.length}개 ($names)'
        : '인물 $index 층: ${parts.length}개 찾음 · 사용자가 끔';
  }

  /// Which segmenter actually produced the cutout. The engine is recorded by
  /// [segmentAndAnalyze]; older drafts without it fall back to ML Kit.
  static String engineLabel(Map<String, dynamic> person) =>
      person['segmented'] != true
      ? '원본 데모'
      : person['segmentationEngine'] == 'modnet'
      ? 'MODNet 누끼'
      : 'ML Kit 누끼';

  static String cropLabel(String type) => switch (type) {
    'FULL_BODY' => '전신',
    'HALF_BODY' => '반신',
    'UPPER_BODY' => '상반신',
    _ => '분류 불가',
  };
  static List<String> validateDraft(
    MemoryConcert? concert,
    String? background,
    List<Map<String, dynamic>> people,
  ) => [
    if (concert == null) '공연을 선택해주세요.',
    if (background == null) '배경 사진을 선택해주세요.',
    if (people.isEmpty) '메인 인물을 선택해주세요.',
    if (people.length > 2) '인물은 두 명까지 선택할 수 있어요.',
  ];
}
