import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/creation_service.dart';
import 'package:timo/features/memory/models/photo_framing.dart';

/// 어떤 비율의 사진을 넣어도 배경은 카드 비율(9:14)로 나와야 한다.
///
/// 비율을 맞추는 일은 Dart 의 [PhotoFraming] 이 하고(cover 는 잘라 채우고,
/// contain 은 단색 여백을 둔다), 네이티브 깊이 단계는 그렇게 만들어진 그림을
/// 그대로 받는다. 예전에는 네이티브가 미러+블러로 letterbox 를 채웠는데,
/// 배경이 늘 카드 비율로 넘어와 한 번도 실행되지 않아 걷어냈다.
///
/// 결과는 background_cover.png / background_contain.png 로 남겨 눈으로도
/// 확인할 수 있게 한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('가로 사진도 배경은 카드 비율로 나온다', (tester) async {
    final service = CreationService();
    final source = await service.copyPhotoToPrivateStorage(
      'assets/demo/pose_test.jpg',
      asset: true,
    );
    final original = await _decode(source);
    expect(
      original.width,
      greaterThan(original.height),
      reason: '가로 사진이어야 이 테스트가 의미가 있다',
    );

    final folder = await getApplicationDocumentsDirectory();

    for (final (framing, name) in [
      (const PhotoFraming(), 'background_cover'),
      (const PhotoFraming(contain: true), 'background_contain'),
    ]) {
      final prepared = await service.prepareBackground(
        source,
        framing: framing,
      );
      final path = prepared.depth['backgroundPath'] as String;
      final background = await _decode(path);
      try {
        expect(
          background.width / background.height,
          closeTo(ViewerConstants.cardAspect, 0.01),
          reason: '$name 이 카드 비율이 아니다',
        );
      } finally {
        background.dispose();
      }
      await File(path).copy('${folder.path}/$name.png');
    }
    original.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}
