import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/goods_api.dart';
import 'package:timo/features/memory/data/goods_restore_service.dart';
import 'package:timo/features/memory/models/goods_record.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';
import 'package:timo/features/memory/models/ticket_effect.dart';

/// 상세 하나만 돌려주는 서버.
class _DetailGoodsApi extends MockGoodsApi {
  _DetailGoodsApi(this.detail);
  final GoodsDetail detail;

  @override
  Future<GoodsDetail> fetchDetail(String goodsId) async => detail;
}

/// 서버 상세 응답. 실제 `GoodsDetailResponseDto` 모양이고, `personLayers` 는 앱이
/// 올린 JSON 에 서버가 `*Url` 을 덧붙인 것이다.
GoodsDetail _detail({String? backgroundUrl = 'https://cdn.test/g/7/bg.png'}) =>
    GoodsDetail.fromJson({
      'goodsId': 7,
      'ticketId': 1024,
      'concertId': 3,
      'clientGoodsId': '1024',
      'backgroundKey': 'goods/1/1024/bg.png',
      'backgroundUrl': backgroundUrl,
      'sourceBackgroundUrl': 'https://cdn.test/g/7/source.jpg',
      'personCompositeUrl': 'https://cdn.test/g/7/people.png',
      'depthMapUrl': 'https://cdn.test/g/7/depth.png',
      'previewUrl': null,
      'effectType': 'godRays',
      'backgroundFraming': {
        'contain': false,
        'scale': 1.8,
        'x': -0.5,
        'y': 0.2,
      },
      'personLayers': [
        {
          'cutoutKey': 'k2',
          'cutoutUrl': 'https://cdn.test/g/7/p2.png',
          'depthStrength': 'off',
          'layered': false,
          'left': 0.5,
          'top': 0.25,
          'width': 0.3,
          'height': 0.5,
          'layerOrder': 1,
          'parts': [],
        },
        {
          'cutoutKey': 'k1',
          'cutoutUrl': 'https://cdn.test/g/7/p1.png',
          'depthMapKey': 'k1d',
          'depthMapUrl': 'https://cdn.test/g/7/p1-depth.png',
          'depthStrength': 'strong',
          'layered': true,
          'left': 0.1,
          'top': 0.2,
          'width': 0.3,
          'height': 0.5,
          'layerOrder': 0,
          'parts': [
            {
              'label': 'head',
              'depth': 0.8,
              'share': 0.2,
              'partMapKey': 'k1p',
              'partMapUrl': 'https://cdn.test/g/7/p1-parts.png',
            },
            {
              'label': 'torso',
              'depth': 0.5,
              'share': 0.8,
              'partMapKey': 'k1p',
              'partMapUrl': 'https://cdn.test/g/7/p1-parts.png',
            },
          ],
        },
      ],
      'transitionConfig': {'brightness': 0.05, 'firstFrameAnalyzed': true},
      'renderMetadata': {'demoDepth': false, 'manualPersonLayout': true},
      'concertSnapshot': {
        'title': '빛으로 남은 밤',
        'artist': 'TIMO STAGE',
        'date': '2026-09-26T19:00:00',
        'venue': '서울 메모리 홀',
      },
      'createdAt': '2026-09-27T10:00:00',
    });

void main() {
  late Directory root;
  late List<String> downloaded;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('timo_restore');
    downloaded = [];
  });

  tearDown(() => root.delete(recursive: true));

  GoodsRestoreService service(GoodsDetail detail) => GoodsRestoreService(
    _DetailGoodsApi(detail),
    documentsDirectory: () async => root,
    download: (url, target) async {
      downloaded.add(url);
      await File(target).writeAsBytes(const [1, 2, 3]);
    },
  );

  test('상세의 주소마다 내려받아 기기 경로로 된 확정 소장품을 만든다', () async {
    final ticket = await service(_detail()).restore('7');

    expect(ticket.ticketId, '1024');
    expect(ticket.concertId, '3');
    expect(ticket.goodsId, '7');
    expect(ticket.confirmed, isTrue);
    expect(ticket.effect, TicketEffect.godRays);
    expect(ticket.manualPersonLayout, isTrue);
    expect(ticket.demoDepth, isFalse);
    expect(ticket.backgroundFraming?.scale, 1.8);
    expect(ticket.transition['brightness'], 0.05);

    // 전부 이 기기 파일이고, 소장품 번호 아래에 모여 있다.
    final paths = [
      ticket.backgroundPath,
      ticket.sourceBackgroundPath!,
      ticket.personCompositePath!,
      ticket.depthMapPath!,
    ];
    for (final path in paths) {
      // 앱 문서 폴더 아래 `photos/restored/{goodsId}/` 에 놓인다.
      expect(path, startsWith(root.path));
      expect(path, contains('/photos/restored/7/'));
      expect(File(path).existsSync(), isTrue);
    }
    // 원본 확장자를 따라간다 — jpg 를 png 라고 저장하면 디코더가 헷갈린다.
    expect(ticket.sourceBackgroundPath, endsWith('.jpg'));
    // 미리보기는 올리지 않았으니 받을 것도 없다.
    expect(ticket.previewImagePath, isNull);
    expect(downloaded, isNot(contains(null)));
  });

  test('인물 층은 layerOrder 순으로 복원되고 부위 맵은 부위 주소에서 받는다', () async {
    final ticket = await service(_detail()).restore('7');

    expect(ticket.personDepthLayers, hasLength(2));
    final [first, second] = ticket.personDepthLayers;
    expect(first.order, 0);
    expect(second.order, 1);

    expect(first.strength, PersonDepthStrength.strong);
    expect(first.layered, isTrue);
    expect(first.depthMapPath, isNotNull);
    expect(first.partMapPath, isNotNull);
    expect(first.parts.map((p) => p.label), ['head', 'torso']);
    expect(first.usesPartLayers, isTrue);
    expect(first.placement.left, closeTo(0.1, 1e-9));
    expect(first.placement.height, closeTo(0.5, 1e-9));

    expect(second.strength, PersonDepthStrength.off);
    expect(second.depthMapPath, isNull);
    expect(second.partMapPath, isNull);
    expect(second.parts, isEmpty);

    // 부위 맵 한 장은 한 번만 받는다 — 부위 둘이 같은 주소를 가리켜도.
    expect(downloaded.where((u) => u.endsWith('p1-parts.png')).length, 1);
  });

  test('뒷면은 서버가 기억하는 공연 정보로 찍힌다', () async {
    final ticket = await service(_detail()).restore('7');

    // 카탈로그의 ticketDetails 와 같은 키·같은 문구 형식이다.
    expect(ticket.details, {
      '공연명': '빛으로 남은 밤',
      '아티스트': 'TIMO STAGE',
      '날짜': '2026.09.26',
      '시간': '19:00',
      '장소': '서울 메모리 홀',
    });
    expect(ticket.processingNotes, [GoodsText.restoredNote]);
    // 공연에 영상이 없어 만들 때도 데모 영상이었다.
    expect(ticket.videoUrl, CatalogConstants.demoVideoAsset);
  });

  test('배경 주소가 없으면 복원할 수 없다', () {
    expect(
      () => service(_detail(backgroundUrl: null)).restore('7'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          GoodsText.restoreFailed,
        ),
      ),
    );
  });
}
