import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';
import 'package:timo/features/memory/models/photo_framing.dart';
import 'package:timo/features/memory/models/person_depth_layer.dart';

import 'dart:ui';

import 'package:timo/features/memory/data/ticket_store.dart';
import 'package:timo/features/memory/data/creation_service.dart';

void main() {
  test(
    'ticket survives closing and reopening Hive with all rendering metadata',
    () async {
      final folder = await Directory.systemTemp.createTemp('timo_test');
      Hive.init(folder.path);
      var box = await Hive.openBox<String>('test');
      const ticket = MemoryTicket(
        ticketId: '1',
        concertId: 'c',
        backgroundPath: 'photo.png',
        sourceBackgroundPath: 'original.png',
        backgroundFraming: PhotoFraming(scale: 1.8, x: -0.5, y: 0.2),
        personCompositePath: 'people.png',
        manualPersonLayout: true,
        personDepthLayers: [
          PersonDepthLayer(
            path: 'person.png',
            depthMapPath: 'person-depth.png',
            placement: Rect.fromLTWH(0.1, 0.2, 0.3, 0.5),
          ),
          PersonDepthLayer(
            path: 'person2.png',
            depthMapPath: 'person2-depth.png',
            placement: Rect.fromLTWH(0.5, 0.2, 0.3, 0.5),
            strength: PersonDepthStrength.off,
            order: 1,
          ),
        ],
        effectType: '꽃가루',
        videoId: 'v',
        videoUrl: 'assets/videos/demo.mp4',
        details: {'공연명': '데모'},
        depthLayers: ['a', 'b', 'c'],
        demoDepth: true,
        transition: {'durationMs': 650},
      );
      await HiveTicketStore(box).save(ticket);
      await box.close();
      box = await Hive.openBox<String>('test');
      final restored = HiveTicketStore(box).readAll().single;
      expect(restored.toJson(), ticket.toJson());
      final changed = restored.copyWith(
        personDepthLayers: [
          restored.personDepthLayers[0].withStrength(
            PersonDepthStrength.strong,
          ),
          restored.personDepthLayers[1],
        ],
      );
      await HiveTicketStore(box).save(changed);
      final changedRestored = HiveTicketStore(box).readAll().single;
      expect(
        changedRestored.personDepthLayers[0].strength,
        PersonDepthStrength.strong,
      );
      expect(
        changedRestored.personDepthLayers[1].strength,
        PersonDepthStrength.off,
      );
      expect(
        changedRestored.personDepthLayers[0].placement,
        ticket.personDepthLayers[0].placement,
      );
      await HiveTicketStore(box).delete('1');
      expect(HiveTicketStore(box).readAll(), isEmpty);
      await box.close();
      await folder.delete(recursive: true);
    },
  );
  test('민팅 키가 남아 있는 예전 레코드도 그대로 읽힌다', () {
    // 블록체인을 쓰지 않기로 하면서 mintStatus·tokenId·transactionHash·
    // metadataUrl 을 지웠다. 이미 기기에 저장된 레코드에는 그 키들이 남아
    // 있는데, 모르는 키는 그냥 지나가므로 옮길 것이 없다는 걸 못 박는다.
    final stored = <String, dynamic>{
      'ticketId': '1',
      'concertId': 'c',
      'ownerId': 'local-demo',
      'backgroundPath': 'photo.png',
      'personCompositePath': 'people.png',
      'effectType': '레이저',
      'videoId': 'v',
      'videoUrl': 'v.mp4',
      'details': <String, String>{'공연명': '밤'},
      'depthLayers': <String>['a.png'],
      'demoDepth': false,
      'processingNotes': <String>[],
      'transition': <String, dynamic>{},
      // 여기부터가 이제 쓰지 않는 키들.
      'mintStatus': 'NOT_MINTED',
      'metadataUrl': 'https://example.com/1.json',
      'tokenId': '42',
      'transactionHash': '0xabc',
    };

    final ticket = MemoryTicket.fromJson(stored);

    expect(ticket.ticketId, '1');
    expect(ticket.effectType, '레이저');
    expect(ticket.details['공연명'], '밤');
    // 다시 저장하면 쓰지 않는 키는 따라 나가지 않는다.
    expect(ticket.toJson().keys, isNot(contains('mintStatus')));
    expect(ticket.toJson().keys, isNot(contains('tokenId')));
  });

  group('toGoodsJson — 서버 업로드 페이로드', () {
    // 기기 절대 경로처럼 보이는 값을 일부러 넣는다. 결과에 새어 나가면
    // 아래 '로컬 경로가 새지 않는다' 가 잡는다.
    const root = '/data/user/0/com.ssafy.timo/app_flutter';
    const ticket = MemoryTicket(
      ticketId: 'ticket-1',
      concertId: 'concert-1024',
      backgroundPath: '$root/background.png',
      sourceBackgroundPath: '$root/source.png',
      personCompositePath: '$root/people.png',
      depthMapPath: '$root/depth.png',
      previewImagePath: '$root/preview.png',
      backgroundFraming: PhotoFraming(scale: 1.8, x: -0.5, y: 0.2),
      manualPersonLayout: true,
      personDepthLayers: [
        PersonDepthLayer(
          path: '$root/person1.png',
          depthMapPath: '$root/person1-depth.png',
          partMapPath: '$root/person1-parts.png',
          parts: [
            PersonPart(label: 'head', depth: 0.8, share: 0.2),
            PersonPart(label: 'torso', depth: 0.5, share: 0.8),
          ],
          layered: true,
          placement: Rect.fromLTWH(0.1, 0.2, 0.3, 0.5),
          strength: PersonDepthStrength.strong,
        ),
        PersonDepthLayer(
          path: '$root/person2.png',
          depthMapPath: '$root/person2-depth.png',
          placement: Rect.fromLTWH(0.5, 0.25, 0.3, 0.5),
          strength: PersonDepthStrength.off,
          order: 1,
        ),
      ],
      effectType: '빛줄기',
      videoId: 'v',
      videoUrl: 'assets/videos/demo.mp4',
      details: {
        '공연명': '빛으로 남은 밤',
        '아티스트': 'TIMO STAGE',
        '날짜': '2026.09.26',
        '시간': '19:00',
        '장소': '서울 메모리 홀',
        '게이트': 'GATE 2',
        '좌석': '스탠딩 A · 024',
        '예매 번호': 'DEMO-1024',
        '입장 안내': '소장용 데모 티켓입니다.',
      },
      depthLayers: ['$root/band0.png', '$root/band1.png', '$root/band2.png'],
      demoDepth: false,
      transition: {
        'brightness': 0.05,
        'saturation': 1.1,
        'contrast': 1.02,
        'tint': 0xFF203040,
        'durationMs': 610,
        'blur': 9.6,
        'distance': 0.4,
        'firstFrameAnalyzed': true,
      },
    );

    const keys = {
      '$root/background.png': 'goods/1/background.png',
      '$root/source.png': 'goods/1/source.png',
      '$root/people.png': 'goods/1/people.png',
      '$root/depth.png': 'goods/1/depth.png',
      '$root/preview.png': 'goods/1/preview.png',
      '$root/person1.png': 'goods/1/person1.png',
      '$root/person1-depth.png': 'goods/1/person1-depth.png',
      '$root/person2.png': 'goods/1/person2.png',
      '$root/person2-depth.png': 'goods/1/person2-depth.png',
    };

    test('각 컬럼이 올라간다', () {
      final goods = ticket.toGoodsJson(keys: keys);

      expect(goods['client_goods_id'], 'ticket-1');
      expect(goods['concert_id'], 'concert-1024');
      expect(goods['background_key'], 'goods/1/background.png');
      expect(goods['source_background_key'], 'goods/1/source.png');
      expect(goods['person_composite_key'], 'goods/1/people.png');
      expect(goods['depth_map_key'], 'goods/1/depth.png');
      expect(goods['preview_key'], 'goods/1/preview.png');
      // 한국어 라벨('빛줄기')이 아니라 enum 이름으로 나가야 한다.
      expect(goods['effect_type'], 'godRays');
      expect(goods['background_framing'], {
        'contain': false,
        'scale': 1.8,
        'x': -0.5,
        'y': 0.2,
      });
      expect(goods['render_metadata'], {
        'demoDepth': false,
        'manualPersonLayout': true,
      });
      // 좌석·게이트·예매 번호·입장 안내는 소장품에 저장하지 않는다.
      expect(goods['concert_snapshot'], {
        'title': '빛으로 남은 밤',
        'artist': 'TIMO STAGE',
        'date': '2026.09.26',
        'venue': '서울 메모리 홀',
      });
    });

    test('인물 레이어가 DDL 스키마대로 변환된다', () {
      final layers =
          ticket.toGoodsJson(keys: keys)['person_layers']
              as List<Map<String, dynamic>>;

      expect(layers, hasLength(2));
      expect(layers[0], {
        'cutout_key': 'goods/1/person1.png',
        'depth_map_key': 'goods/1/person1-depth.png',
        'depth_strength': 'strong',
        // Rect 는 left·right 로 들고 있어서 width 가 0.30000000000000004 로
        // 나온다. 자리 수까지 못 박을 값이 아니다.
        'left': closeTo(0.1, 1e-9),
        'top': closeTo(0.2, 1e-9),
        'width': closeTo(0.3, 1e-9),
        'height': closeTo(0.5, 1e-9),
        'layer_order': 0,
      });
      expect(layers[1]['depth_strength'], 'off');
      expect(layers[1]['layer_order'], 1);
    });

    test('배경 시차용 밴드는 보내지 않는다', () {
      // 로컬 경로일 뿐이라 다른 기기에서 의미가 없다. depth_map_key 로
      // 셰이더가 다시 만든다.
      final goods = ticket.toGoodsJson(keys: keys);
      expect(goods['render_metadata'], isNot(contains('depthLayers')));
      expect(goods.toString(), isNot(contains('band0')));
    });

    test('분석이 실패한 전환 설정은 중립값으로 채워진다', () {
      // 전환 분석이 예외로 실패하면 이 한 키만 남는다(CreationService).
      const failed = MemoryTicket(
        ticketId: 't',
        concertId: 'c',
        backgroundPath: 'bg.png',
        personCompositePath: null,
        effectType: '효과 없음',
        videoId: 'v',
        videoUrl: 'v.mp4',
        details: {},
        depthLayers: [],
        demoDepth: true,
        transition: {'firstFrameAnalyzed': false},
      );

      final config =
          failed.toGoodsJson(keys: const {'bg.png': 'k'})['transition_config']
              as Map<String, dynamic>;

      // 사진과 첫 프레임이 같다(distance 0)고 볼 때의 값과 같다.
      expect(config['brightness'], 0.0);
      expect(config['saturation'], 1.0);
      expect(config['contrast'], 1.0);
      expect(config['durationMs'], 550);
      expect(config['blur'], 8.0);
      expect(config['distance'], 0.0);
      expect(config['firstFrameAnalyzed'], false);
      // 곱셈 항등원. 검정을 넣으면 나중에 곱하는 순간 화면이 죽는다.
      expect(config['tint'], 0xFFFFFFFF);
    });

    test('분석에 성공한 전환 설정은 그대로 간다', () {
      final config =
          ticket.toGoodsJson(keys: keys)['transition_config']
              as Map<String, dynamic>;

      expect(config['brightness'], 0.05);
      expect(config['saturation'], 1.1);
      expect(config['contrast'], 1.02);
      expect(config['tint'], 0xFF203040);
      expect(config['durationMs'], 610);
      expect(config['blur'], 9.6);
      expect(config['distance'], 0.4);
      expect(config['firstFrameAnalyzed'], true);
    });

    test('로컬 경로가 하나도 새지 않는다', () {
      // 기기 경로가 섞여 나가면 다른 기기에서 복원할 때 깨진 링크가 된다.
      final dumped = jsonEncode(ticket.toGoodsJson(keys: keys));

      expect(dumped, isNot(contains(root)));
      expect(dumped, isNot(contains('/data/')));
      expect(dumped, isNot(contains('Android/data')));
      expect(dumped, isNot(contains('app_flutter')));
      expect(
        RegExp(r'"[^"]*/storage/').hasMatch(dumped),
        false,
        reason: '외부 저장소 경로가 남았다',
      );
    });

    test('배경 키가 없으면 바로 실패한다', () {
      // background_key 는 NOT NULL 이다. 여기서 안 던지면 서버가 거절할
      // 때까지 모른다.
      expect(
        () => ticket.toGoodsJson(keys: const {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('필수가 아닌 경로는 키가 없으면 null 로 둔다', () {
      final goods = ticket.toGoodsJson(
        keys: const {'$root/background.png': 'goods/1/background.png'},
      );

      expect(goods['background_key'], 'goods/1/background.png');
      expect(goods['source_background_key'], isNull);
      expect(goods['person_composite_key'], isNull);
      expect(goods['depth_map_key'], isNull);
      expect(goods['preview_key'], isNull);
      expect(
        (goods['person_layers'] as List).first,
        containsPair('cutout_key', isNull),
      );
    });
  });

  test('draft validation returns all errors', () {
    expect(CreationService.validateDraft(null, null, []), hasLength(3));
  });
}
