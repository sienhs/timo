import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'person_auto_layout.dart';
import 'person_placement.dart';

/// 사람 사진들을 티켓 캔버스(900 × 1400) 한 장으로 합친다.
///
/// 합성 자체는 전부 Dart 다. 네이티브에 남는 것은 [analyze] 하나 — 인물 분석은
/// ML Kit·MediaPipe 를 타야 해서 Kotlin 이 아니면 안 된다. 나머지(어디에 얼마나
/// 크게 놓을지 계산하고 캔버스에 그리는 일)는 `dart:ui` 로 충분해서 예전
/// `CompositionProcessor.kt` 를 걷어내고 여기로 옮겼다.
///
/// 별도 아이솔레이트를 쓰지 않는 이유: 무거운 두 단계가 이미 UI 스레드 밖에서
/// 돈다. 디코드는 엔진 워커가, [ui.Picture.toImage] 래스터화는 래스터 스레드가
/// 한다. 남는 Dart 코드는 사각형 몇 개 계산하는 게 전부라 아이솔레이트로 보내면
/// 왕복 비용만 는다. (`dart:ui` 의 Canvas·toImage 는 메인 아이솔레이트 밖에서는
/// 쓸 수도 없다.)
class CompositionService {
  static const _channel = MethodChannel('timo/image_pipeline');

  Future<Map<String, dynamic>> analyze(String path) async =>
      Map<String, dynamic>.from(
        (await _channel.invokeMapMethod<String, dynamic>('analyzePerson', {
          'path': path,
        }))!,
      );

  /// 합성본 PNG 를 만들어 그 경로를 돌려준다.
  ///
  /// 모두가 손으로 잡은 배치([PersonPlacement])를 들고 있으면 그대로 쓰고,
  /// 하나라도 없으면 사진 속 몸 비율로 [PersonAutoLayout] 이 대신 앉힌다.
  /// 섞지 않는 이유는 자동 배치가 한 사람씩이 아니라 전체를 한 덩어리로 보고
  /// 여백에 맞추기 때문이다 — 절반만 적용하면 그 맞춤이 깨진다.
  Future<String> compose(List<Map<String, dynamic>> people) async {
    if (people.isEmpty) throw ArgumentError('합성할 사람이 없습니다');
    final images = <ui.Image>[];
    try {
      for (final person in people) {
        images.add(await _decode(person['path'] as String));
      }
      final placed = people.every((p) => p['placement'] != null);
      final rects = placed
          ? [
              for (final person in people)
                PersonPlacement.fromPerson(
                  person,
                ).inCanvas(PersonPlacement.canvasSize),
            ]
          : PersonAutoLayout.layout(people, [
              for (final image in images)
                ui.Size(image.width.toDouble(), image.height.toDouble()),
            ]);
      // await 없이 돌려주면 아래 finally 가 먼저 돌아 그리는 도중에
      // 이미지가 dispose 된다.
      return await _render(people, images, rects);
    } finally {
      for (final image in images) {
        image.dispose();
      }
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

  /// 새로 들어온 사람에게만 처음 크기를 준다. 이미 잡아 둔 배치는 살린다.
  Future<void> initializePlacement(
    Map<String, dynamic> person,
    int index,
  ) async {
    final image = await _decode(person['path'] as String);
    try {
      final placement = PersonPlacement.initial(
        ui.Size(image.width.toDouble(), image.height.toDouble()),
        index,
      );
      person['placement'] = placement.toJson();
      person['initialPlacement'] = placement.toJson();
      person['order'] = index;
    } finally {
      image.dispose();
    }
  }

  /// [rects] 자리에 [images] 를 그려 PNG 로 저장한다. `order` 가 작은 사람이
  /// 먼저(뒤에) 그려지므로 큰 쪽이 앞으로 온다.
  Future<String> _render(
    List<Map<String, dynamic>> people,
    List<ui.Image> images,
    List<ui.Rect> rects,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final order = people.asMap().keys.toList()
      ..sort(
        (a, b) => ((people[a]['order'] as num?) ?? a).compareTo(
          (people[b]['order'] as num?) ?? b,
        ),
      );
    for (final i in order) {
      final image = images[i];
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        rects[i],
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
    }
    final picture = recorder.endRecording();
    late final ui.Image output;
    try {
      output = await picture.toImage(
        PersonPlacement.canvasSize.width.round(),
        PersonPlacement.canvasSize.height.round(),
      );
    } finally {
      picture.dispose();
    }
    try {
      final bytes = (await output.toByteData(format: ui.ImageByteFormat.png))!;
      final root = await getApplicationDocumentsDirectory();
      final folder = await Directory(
        '${root.path}/composites',
      ).create(recursive: true);
      final file = File(
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      return file.path;
    } finally {
      output.dispose();
    }
  }
}
