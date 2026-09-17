import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/models/memory_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('timo/image_pipeline');
  const legacy = MemoryTicket(
    ticketId: 'legacy',
    concertId: 'concert',
    backgroundPath: 'cached-background.png',
    sourceBackgroundPath: 'original.jpg',
    personCompositePath: 'saved-person.png',
    effectType: '레이저',
    videoId: 'video',
    videoUrl: 'assets/videos/official_demo.mp4',
    details: {'title': '기존 소장품'},
    depthLayers: ['old-band.png'],
    depthMapPath: 'old-depth.png',
    demoDepth: true,
    processingNotes: ['배경 확장: 생성형 AI 아웃페인팅으로 카드를 채움'],
  );
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'legacy demo upgrades locally and real depth is reused on next open',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'depth');
            expect(call.arguments['path'], legacy.backgroundPath);
            return {
              'demo': false,
              'backgroundPath': 'prepared.png',
              'layers': ['far.png', 'mid.png', 'near.png'],
              'depthMapPath': 'real-depth.png',
            };
          });
      final service = CreationService();
      final upgraded = await service.upgradeBackground(legacy);
      expect(upgraded.demoDepth, false);
      expect(upgraded.depthMapPath, 'real-depth.png');
      expect(upgraded.personCompositePath, legacy.personCompositePath);
      expect(upgraded.sourceBackgroundPath, legacy.sourceBackgroundPath);
      expect(upgraded.processingNotes, legacy.processingNotes);
      expect(upgraded.ticketId, legacy.ticketId);
      expect(await service.upgradeBackground(upgraded), same(upgraded));
      expect(calls, 1);
    },
  );

  test(
    'failed inference preserves the existing ticket and cached images',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => {'demo': true});
      final service = CreationService();
      expect(await service.upgradeBackground(legacy), same(legacy));
    },
  );
}
