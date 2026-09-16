import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_scopes.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/screens/creator_screen.dart';
import 'package:timo/features/memory/theme/memory_theme.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/background_extension_service.dart';
import 'package:timo/features/memory/data/outpaint_service.dart';
import 'package:timo/features/memory/models/memory_concert.dart';

/// Stands in for the paid gpt-image-2 call: counts invocations and hands back
/// a ready-made "extended" file.
class _FakeExtension extends BackgroundExtensionService {
  _FakeExtension(this.output) : super(const NoOutpaintService());
  final String output;
  int calls = 0;
  @override
  bool get available => true;
  @override
  Future<BackgroundExtension> extendToAspect(
    String path,
    double targetAspect,
  ) async {
    calls++;
    return BackgroundExtension(
      BackgroundExtensionOutcome.generated,
      path: output,
    );
  }
}

/// Hands back files written before the test started: real file I/O started
/// inside the fake-async zone never completes, so nothing may touch disk here.
class _FakeService extends CreationService {
  _FakeService(this.copied, this.fakeExtension);
  final String copied;
  final _FakeExtension fakeExtension;
  @override
  BackgroundExtensionService get extension => fakeExtension;
  @override
  Future<String> copyPhotoToPrivateStorage(
    String source, {
    bool asset = false,
  }) async => copied;
}

const _concert = MemoryConcert(
  id: 'c1',
  title: '테스트 공연',
  artist: '아티스트',
  date: '2026-09-15',
  venue: '홀',
  poster: 'assets/demo/stage_blue.png',
  videoUrl: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The creator asks image_picker for photos lost to process death.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/image_picker'),
          (call) async => null,
        );
  });

  testWidgets('"쓰기" runs the AI once and replaces the framing editor with its '
      'preview; "끄기" restores manual framing without a second call', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Real file I/O never completes inside the fake-async test zone.
    late final Directory folder;
    late final _FakeExtension extension;
    late final _FakeService service;
    await tester.runAsync(() async {
      folder = await Directory.systemTemp.createTemp('creator_ai');
      Future<String> write(String asset, String name) async {
        final data = await rootBundle.load(asset);
        final file = File('${folder.path}/$name');
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        return file.path;
      }

      extension = _FakeExtension(
        await write('assets/demo/stage_gold.png', 'extended.png'),
      );
      service = _FakeService(
        await write('assets/demo/stage_blue.png', 'photo.png'),
        extension,
      );
    });
    addTearDown(() async {
      try {
        await folder.delete(recursive: true);
      } on FileSystemException {
        // Windows keeps a handle open while a decode is still in flight.
      }
    });

    Future<void> settle() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.pumpWidget(
      withMemoryScopes(
        MaterialApp(
          theme: timoTheme(),
          home: CreatorScreen(initialConcert: _concert, service: service),
        ),
      ),
    );
    await settle();
    expect(find.text('2/5'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('${CreatorText.stageLabel} 1'));
    await settle();
    expect(find.text(BackgroundExtensionConstants.aiTitle), findsOneWidget);
    expect(find.text('프레임 채우기'), findsOneWidget);

    // 쓰기 → exactly one AI call; the preview replaces the framing controls.
    await tester.ensureVisible(
      find.text(BackgroundExtensionConstants.aiUseLabel),
    );
    await tester.tap(find.text(BackgroundExtensionConstants.aiUseLabel));
    await settle();
    expect(extension.calls, 1);
    expect(find.text(BackgroundExtensionConstants.aiStopLabel), findsOneWidget);
    expect(
      find.text(BackgroundExtensionConstants.aiPreviewNote),
      findsOneWidget,
    );
    expect(find.text('프레임 채우기'), findsNothing);
    expect(find.text(CreatorText.nextLabel), findsOneWidget);

    // 끄기 → manual framing is back; pressing 쓰기 again reuses the result.
    await tester.tap(find.text(BackgroundExtensionConstants.aiStopLabel));
    await settle();
    expect(find.text('프레임 채우기'), findsOneWidget);
    await tester.tap(find.text(BackgroundExtensionConstants.aiUseLabel));
    await settle();
    expect(extension.calls, 1);
    expect(find.text(BackgroundExtensionConstants.aiStopLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
