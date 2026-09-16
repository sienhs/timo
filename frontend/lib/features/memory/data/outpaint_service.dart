import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../constants.dart';
import 'outpaint_canvas.dart';

/// How many pixels to add on each side so a photo reaches a target aspect.
class OutpaintPlan {
  const OutpaintPlan({
    required this.left,
    required this.right,
    required this.up,
    required this.down,
  });
  final int left, right, up, down;

  bool get isEmpty => left == 0 && right == 0 && up == 0 && down == 0;
  bool get isPortraitTarget => up + down > 0;

  /// Splits the missing height (or width) evenly, capped per side to the
  /// provider limit. Returns an empty plan when the aspect already matches.
  factory OutpaintPlan.forAspect({
    required int width,
    required int height,
    required double targetAspect,
    double tolerance = BackgroundExtensionConstants.aspectTolerance,
    int maxPerSide = BackgroundExtensionConstants.maxExtensionPerSide,
  }) {
    final aspect = width / height;
    if ((aspect - targetAspect).abs() < tolerance) {
      return const OutpaintPlan(left: 0, right: 0, up: 0, down: 0);
    }
    if (aspect > targetAspect) {
      final targetHeight = (width / targetAspect).round();
      final each = ((targetHeight - height) / 2).round().clamp(0, maxPerSide);
      return OutpaintPlan(left: 0, right: 0, up: each, down: each);
    }
    final targetWidth = (height * targetAspect).round();
    final each = ((targetWidth - width) / 2).round().clamp(0, maxPerSide);
    return OutpaintPlan(left: each, right: each, up: 0, down: 0);
  }
}

/// Generative outpainting: invents plausible pixels beyond the photo edges.
/// Implementations return an image covering the padded canvas; the caller
/// pastes the original back in the centre.
abstract interface class OutpaintService {
  bool get available;
  String get label;
  Future<Uint8List> outpaint({
    required Uint8List image,
    required OutpaintPlan plan,
    required String prompt,
  });
}

/// Disabled provider: never called when [available] is false.
class NoOutpaintService implements OutpaintService {
  const NoOutpaintService();
  @override
  bool get available => false;
  @override
  String get label => 'none';
  @override
  Future<Uint8List> outpaint({
    required Uint8List image,
    required OutpaintPlan plan,
    required String prompt,
  }) => throw const ApiException('AI 배경 확장이 설정되지 않았어요.');
}

Dio _client(Dio? client) =>
    client ??
    Dio(
      BaseOptions(
        connectTimeout: BackgroundExtensionConstants.connectTimeout,
        receiveTimeout: BackgroundExtensionConstants.receiveTimeout,
      ),
    );

Never _fail(String message) => throw ApiException(message);

/// Accepts a bare origin, a gateway prefix, or a full endpoint copied from
/// docs (e.g. `.../api.openai.com/v1/images/generations`) and returns the
/// part before the API version segment, without a trailing slash.
String normalizeBaseUrl(String url, String fallback, {String version = '/v1'}) {
  if (url.isEmpty) return fallback;
  var base = url.trim();
  final marker = base.indexOf('$version/');
  if (marker >= 0) {
    base = base.substring(0, marker);
  } else if (base.endsWith(version)) {
    base = base.substring(0, base.length - version.length);
  }
  return base.replaceAll(RegExp(r'/+$'), '');
}

/// OpenAI Images API `POST {base}/v1/images/edits` (gpt-image-2 by default;
/// gpt-image-1, -1-mini and -1.5 accept the same request). The photo is
/// padded onto a transparent canvas and sent with a mask; transparent pixels
/// are where the model paints. Works unchanged through OpenAI-compatible
/// gateways such as GMS when [baseUrl] points at them (verified 2026-09-15:
/// gms.ssafy.io + gpt-image-2 edits → 200, ~10 s).
class OpenAiOutpaintService implements OutpaintService {
  OpenAiOutpaintService(
    this.apiKey, {
    String? baseUrl,
    String? model,
    Dio? client,
  }) : baseUrl = normalizeBaseUrl(baseUrl ?? '', defaultBaseUrl),
       model = (model == null || model.isEmpty) ? defaultModel : model,
       _dio = _client(client);
  static const defaultBaseUrl = 'https://api.openai.com';
  static const defaultModel = 'gpt-image-2';
  final String apiKey, baseUrl, model;
  final Dio _dio;

  @override
  bool get available => apiKey.isNotEmpty;
  @override
  String get label => 'OpenAI $model';

  /// gpt-image models only render fixed sizes; pick the closest aspect.
  static String sizeFor(OutpaintPlan plan) =>
      plan.isPortraitTarget ? '1024x1536' : '1536x1024';

  @override
  Future<Uint8List> outpaint({
    required Uint8List image,
    required OutpaintPlan plan,
    required String prompt,
  }) async {
    final padded = await OutpaintCanvas.pad(image, plan);
    final mask = await OutpaintCanvas.mask(image, plan);
    final form = FormData.fromMap({
      'model': model,
      'prompt': prompt,
      'size': sizeFor(plan),
      'n': 1,
      'image': MultipartFile.fromBytes(
        padded,
        filename: 'photo.png',
        contentType: DioMediaType('image', 'png'),
      ),
      'mask': MultipartFile.fromBytes(
        mask,
        filename: 'mask.png',
        contentType: DioMediaType('image', 'png'),
      ),
    });
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/v1/images/edits',
        data: form,
        options: Options(
          headers: {'authorization': 'Bearer $apiKey'},
          responseType: ResponseType.json,
        ),
      );
      final data = response.data?['data'];
      if (response.statusCode != 200 || data is! List || data.isEmpty) {
        _fail('AI 배경 확장에 실패했어요.');
      }
      final first = data.first as Map;
      final b64 = first['b64_json'] as String?;
      if (b64 != null) return base64Decode(b64);
      final url = first['url'] as String?;
      if (url == null) _fail('AI 배경 확장 결과가 비어 있어요.');
      final bytes = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(bytes.data ?? _fail('AI 결과 다운로드 실패'));
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      final body = e.response?.data;
      final detail = body is Map ? (body['error']?['message'] ?? '') : '';
      _fail('AI 배경 확장 서버 오류 (${e.response?.statusCode ?? '연결 실패'}) $detail');
    } catch (_) {
      _fail('AI 배경 확장 서버에 연결할 수 없어요.');
    }
  }
}

/// Google Gemini image model `POST {base}/v1beta/models/{model}:generateContent`
/// (gemini-2.5-flash-image). Gemini has no mask input, so the photo is
/// padded with a flat grey band and the prompt asks for that band to be
/// painted; the caller pastes the original back afterwards.
class GeminiOutpaintService implements OutpaintService {
  GeminiOutpaintService(
    this.apiKey, {
    String? baseUrl,
    String? model,
    Dio? client,
  }) : baseUrl = normalizeBaseUrl(
         baseUrl ?? '',
         defaultBaseUrl,
         version: '/v1beta',
       ),
       model = (model == null || model.isEmpty) ? defaultModel : model,
       _dio = _client(client);
  static const defaultBaseUrl = 'https://generativelanguage.googleapis.com';
  static const defaultModel = 'gemini-2.5-flash-image';
  static const bandFill = 0xFF7A7A7A;
  final String apiKey, baseUrl, model;
  final Dio _dio;

  @override
  bool get available => apiKey.isNotEmpty;
  @override
  String get label => 'Gemini $model';

  @override
  Future<Uint8List> outpaint({
    required Uint8List image,
    required OutpaintPlan plan,
    required String prompt,
  }) async {
    final padded = await OutpaintCanvas.pad(
      image,
      plan,
      fill: const Color(bandFill),
    );
    final body = {
      'contents': [
        {
          'parts': [
            {
              'text':
                  '$prompt Replace only the flat grey bands at the edges with '
                  'a seamless continuation of the photo. Keep the photo in '
                  'the middle exactly as it is and keep the image size.',
            },
            {
              'inline_data': {
                'mime_type': 'image/png',
                'data': base64Encode(padded),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseModalities': ['IMAGE', 'TEXT'],
      },
    };
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/v1beta/models/$model:generateContent',
        data: body,
        options: Options(
          headers: {
            'x-goog-api-key': apiKey,
            'content-type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );
      final candidates = response.data?['candidates'];
      if (response.statusCode != 200 ||
          candidates is! List ||
          candidates.isEmpty) {
        _fail('AI 배경 확장에 실패했어요.');
      }
      final parts = (candidates.first as Map)['content']?['parts'];
      if (parts is List) {
        for (final part in parts) {
          final inline = (part as Map)['inline_data'] ?? part['inlineData'];
          final data = inline is Map ? inline['data'] as String? : null;
          if (data != null) return base64Decode(data);
        }
      }
      _fail('AI 배경 확장 결과에 이미지가 없어요.');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      final body = e.response?.data;
      final detail = body is Map ? (body['error']?['message'] ?? '') : '';
      _fail('AI 배경 확장 서버 오류 (${e.response?.statusCode ?? '연결 실패'}) $detail');
    } catch (_) {
      _fail('AI 배경 확장 서버에 연결할 수 없어요.');
    }
  }
}

/// Stability AI `stable-image/edit/outpaint`: multipart upload of the photo
/// plus per-side pixel counts, PNG bytes back.
class StabilityOutpaintService implements OutpaintService {
  StabilityOutpaintService(this.apiKey, {String? baseUrl, Dio? client})
    : baseUrl = (baseUrl == null || baseUrl.isEmpty)
          ? defaultBaseUrl
          : baseUrl.replaceAll(RegExp(r'/+$'), ''),
      _dio = _client(client);
  static const defaultBaseUrl = 'https://api.stability.ai';
  static const path = '/v2beta/stable-image/edit/outpaint';
  final String apiKey, baseUrl;
  final Dio _dio;

  @override
  bool get available => apiKey.isNotEmpty;
  @override
  String get label => 'Stability AI outpaint';

  @override
  Future<Uint8List> outpaint({
    required Uint8List image,
    required OutpaintPlan plan,
    required String prompt,
  }) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(image, filename: 'photo.png'),
      'left': plan.left,
      'right': plan.right,
      'up': plan.up,
      'down': plan.down,
      'creativity': BackgroundExtensionConstants.creativity,
      'prompt': prompt,
      'output_format': 'png',
    });
    try {
      final response = await _dio.post<List<int>>(
        '$baseUrl$path',
        data: form,
        options: Options(
          headers: {'authorization': 'Bearer $apiKey', 'accept': 'image/*'},
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = response.data;
      if (response.statusCode != 200 || bytes == null || bytes.isEmpty) {
        _fail('AI 배경 확장에 실패했어요.');
      }
      return Uint8List.fromList(bytes);
    } on ApiException {
      rethrow;
    } catch (_) {
      _fail('AI 배경 확장 서버에 연결할 수 없어요.');
    }
  }
}

/// Picks the provider from build configuration.
OutpaintService outpaintServiceFor({
  required String provider,
  required String apiKey,
  required String baseUrl,
  required String model,
}) {
  if (apiKey.isEmpty) return const NoOutpaintService();
  return switch (provider.toLowerCase()) {
    'gemini' => GeminiOutpaintService(apiKey, baseUrl: baseUrl, model: model),
    'stability' => StabilityOutpaintService(apiKey, baseUrl: baseUrl),
    _ => OpenAiOutpaintService(apiKey, baseUrl: baseUrl, model: model),
  };
}
