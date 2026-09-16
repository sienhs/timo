import 'package:flutter/services.dart';

class SegmentationService {
  static const _channel = MethodChannel('timo/image_pipeline');
  Future<Map<String, dynamic>> cropUpperBody(
    String path,
    double bottom,
  ) async => Map<String, dynamic>.from(
    (await _channel.invokeMapMethod<String, dynamic>('cropUpperBody', {
      'path': path,
      'bottom': bottom,
    }))!,
  );
  Future<Map<String, dynamic>> removeBackground(String path) async =>
      Map<String, dynamic>.from(
        (await _channel.invokeMapMethod<String, dynamic>('segment', {
          'path': path,
        }))!,
      );
}
