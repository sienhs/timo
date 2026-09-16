import 'package:flutter/services.dart';

class DepthService {
  static const _channel = MethodChannel('timo/image_pipeline');

  Future<String?> analyzePerson({
    required String source,
    required String cutout,
    required Map<String, dynamic> crop,
  }) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'personDepth',
        {'source': source, 'cutout': cutout, 'crop': crop},
      );
      return result?['available'] == true
          ? result!['depthMapPath'] as String?
          : null;
    } catch (_) {
      // Preserve the cutout as a fixed image; never substitute synthetic depth.
      return null;
    }
  }

  /// 깊이를 한 번 추론하고 시차용 레이어를 만들어 캐시한다.
  ///
  /// [path] 는 이미 카드 비율로 렌더된 배경이어야 한다
  /// (`CreationService.renderBackground`). 비율을 맞추는 일은 Dart 쪽
  /// `PhotoFraming` 이 하고, 여기는 들어온 그림을 그대로 본다.
  Future<Map<String, dynamic>> analyzeAndCache(String path) async =>
      Map<String, dynamic>.from(
        (await _channel.invokeMapMethod<String, dynamic>('depth', {
          'path': path,
        }))!,
      );
}
