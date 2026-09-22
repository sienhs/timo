import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/goods_api.dart';
import 'package:timo/features/memory/data/goods_uploader.dart';
import 'package:timo/features/memory/models/goods_record.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';

/// 업로드 요청마다 무엇이 실렸는지 적어 두고, key 는 `k:<파일명>` 으로 돌려준다.
class _RecordingGoodsApi extends MockGoodsApi {
  final uploads = <List<String>>[];
  Map<String, dynamic>? created;

  @override
  Future<List<String>> uploadImages({
    required String ticketId,
    required List<String> paths,
  }) async {
    uploads.add(List.of(paths));
    return [for (final path in paths) 'k:${path.split(RegExp(r'[\\/]')).last}'];
  }

  @override
  Future<GoodsDetail> create({
    required String ticketId,
    required Map<String, dynamic> body,
  }) {
    created = body;
    return super.create(ticketId: ticketId, body: body);
  }
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('timo_up'));
  tearDown(() => dir.delete(recursive: true));

  /// [name] 파일을 [bytes] 크기로 만들고 경로를 돌려준다.
  Future<String> file(String name, int bytes) async {
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(List.filled(bytes, 7));
    return f.path;
  }

  test('용량 상한을 넘지 않게 순서대로 나눠 올리고, key 는 원래 자리에 들어간다', () async {
    // 배경 6 + 원본 6 = 12 (상한 10 초과 → 배경 혼자) …
    final ticket = MemoryTicket(
      ticketId: '1024',
      concertId: '3',
      backgroundPath: await file('bg.png', 6),
      sourceBackgroundPath: await file('source.png', 6),
      personCompositePath: await file('people.png', 3),
      depthMapPath: await file('depth.png', 3),
      previewImagePath: await file('preview.png', 9),
      personDepthLayers: [
        PersonDepthLayer(
          path: await file('p1.png', 2),
          depthMapPath: await file('p1-depth.png', 2),
          placement: const Rect.fromLTWH(0, 0, 1, 1),
        ),
      ],
      effectType: '레이저',
      videoId: 'v',
      videoUrl: 'v.mp4',
      details: const {},
      depthLayers: const [],
      demoDepth: false,
    );
    final api = _RecordingGoodsApi();

    await GoodsUploader(api, batchBytes: 10).upload(ticket);

    // 앞에서부터 채우고 넘치면 끊는다: [bg 6], [source 6, people 3], [depth 3],
    // [preview 9], [p1 2, p1-depth 2] — depth(3)+preview(9) 는 12 라 갈린다.
    expect(api.uploads.map((b) => b.map(_name).toList()), [
      ['bg.png'],
      ['source.png', 'people.png'],
      ['depth.png'],
      ['preview.png'],
      ['p1.png', 'p1-depth.png'],
    ]);

    // 나눠 받은 key 가 제 자리에 들어갔다.
    final body = api.created!;
    expect(body['backgroundKey'], 'k:bg.png');
    expect(body['sourceBackgroundKey'], 'k:source.png');
    expect(body['personCompositeKey'], 'k:people.png');
    expect(body['depthMapKey'], 'k:depth.png');
    expect(body['previewKey'], 'k:preview.png');
    final layer = (body['personLayers'] as List).single as Map;
    expect(layer['cutoutKey'], 'k:p1.png');
    expect(layer['depthMapKey'], 'k:p1-depth.png');
  });

  test('상한보다 큰 한 장은 혼자 가고, 상한 안이면 한 요청이다', () async {
    final ticket = MemoryTicket(
      ticketId: '1024',
      concertId: '3',
      backgroundPath: await file('bg.png', 50),
      depthMapPath: await file('depth.png', 1),
      personCompositePath: null,
      effectType: '효과 없음',
      videoId: 'v',
      videoUrl: 'v.mp4',
      details: const {},
      depthLayers: const [],
      demoDepth: true,
    );
    final api = _RecordingGoodsApi();

    await GoodsUploader(api, batchBytes: 10).upload(ticket);
    expect(api.uploads.map((b) => b.map(_name).toList()), [
      ['bg.png'],
      ['depth.png'],
    ]);

    final roomy = _RecordingGoodsApi();
    await GoodsUploader(roomy).upload(ticket);
    expect(roomy.uploads, hasLength(1));
  });

  test('없는 파일은 건너뛰고, 배경이 없으면 올리지 않는다', () async {
    final ticket = MemoryTicket(
      ticketId: '1024',
      concertId: '3',
      backgroundPath: await file('bg.png', 1),
      depthMapPath: '${dir.path}/gone.png',
      personCompositePath: null,
      effectType: '효과 없음',
      videoId: 'v',
      videoUrl: 'v.mp4',
      details: const {},
      depthLayers: const [],
      demoDepth: true,
    );
    final api = _RecordingGoodsApi();
    await GoodsUploader(api).upload(ticket);
    expect(api.uploads.single.map(_name), ['bg.png']);
    expect(api.created!['depthMapKey'], isNull);

    final missing = _RecordingGoodsApi();
    await expectLater(
      GoodsUploader(missing).upload(
        MemoryTicket(
          ticketId: '1',
          concertId: '3',
          backgroundPath: '${dir.path}/none.png',
          personCompositePath: null,
          effectType: '효과 없음',
          videoId: 'v',
          videoUrl: 'v.mp4',
          details: const {},
          depthLayers: const [],
          demoDepth: true,
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          GoodsText.missingBackground,
        ),
      ),
    );
    expect(missing.uploads, isEmpty);
  });
}

String _name(String path) => path.split(RegExp(r'[\\/]')).last;
