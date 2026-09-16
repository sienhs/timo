import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/features/memory/data/outpaint_canvas.dart';
import 'package:timo/features/memory/data/outpaint_service.dart';
import 'package:timo/core/network/api_exception.dart';

/// Captures the outgoing request and answers with canned bytes/status.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.status, required this.body});
  final int status;
  final List<int> body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromBytes(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<Uint8List> _png(int width, int height, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(width, height);
  return OutpaintCanvas.encodePng(image);
}

void main() {
  test('base url accepts origins, prefixes and full endpoints', () {
    const openai = 'https://gms.example/gmsapi/api.openai.com';
    expect(
      normalizeBaseUrl('', 'https://api.openai.com'),
      'https://api.openai.com',
    );
    expect(normalizeBaseUrl('$openai/', 'x'), openai);
    expect(normalizeBaseUrl('$openai/v1', 'x'), openai);
    expect(normalizeBaseUrl('$openai/v1/images/generations', 'x'), openai);
    const gemini =
        'https://gms.example/gmsapi/generativelanguage.googleapis.com';
    expect(
      normalizeBaseUrl(
        '$gemini/v1beta/models/gemini:generateContent',
        'x',
        version: '/v1beta',
      ),
      gemini,
    );
  });

  test('openai defaults to gpt-image-2 and labels the model', () {
    expect(OpenAiOutpaintService.defaultModel, 'gpt-image-2');
    final service = OpenAiOutpaintService('k', model: '');
    expect(service.model, 'gpt-image-2');
    expect(service.label, 'OpenAI gpt-image-2');
    expect(
      outpaintServiceFor(
        provider: 'openai',
        apiKey: 'k',
        baseUrl:
            'https://gms.example/gmsapi/api.openai.com/v1/images/generations',
        model: 'gpt-image-2',
      ).label,
      'OpenAI gpt-image-2',
    );
  });

  test('plan adds equal bands to reach the card aspect and caps per side', () {
    final landscape = OutpaintPlan.forAspect(
      width: 1600,
      height: 1000,
      targetAspect: 9 / 14,
    );
    expect(landscape.left, 0);
    expect(landscape.up, landscape.down);
    expect(1000 + landscape.up + landscape.down, closeTo(1600 / (9 / 14), 2));
    expect(landscape.isPortraitTarget, true);

    final tall = OutpaintPlan.forAspect(
      width: 600,
      height: 1600,
      targetAspect: 9 / 14,
    );
    expect(tall.up, 0);
    expect(tall.left, tall.right);

    expect(
      OutpaintPlan.forAspect(
        width: 900,
        height: 1400,
        targetAspect: 9 / 14,
      ).isEmpty,
      true,
    );
    expect(
      OutpaintPlan.forAspect(
        width: 9000,
        height: 1000,
        targetAspect: 9 / 14,
      ).up,
      2000,
    );
  });

  test('canvas pads, masks and composites at the padded size', () async {
    final photo = await _png(8, 4, const ui.Color(0xFFFF0000));
    const plan = OutpaintPlan(left: 0, right: 0, up: 3, down: 3);
    final padded = await OutpaintCanvas.decode(
      await OutpaintCanvas.pad(photo, plan),
    );
    expect((padded.width, padded.height), (8, 10));
    final mask = await OutpaintCanvas.decode(
      await OutpaintCanvas.mask(photo, plan),
    );
    expect((mask.width, mask.height), (8, 10));
    final generated = await _png(4, 5, const ui.Color(0xFF00FF00));
    final composite = await OutpaintCanvas.decode(
      await OutpaintCanvas.compositeOriginal(generated, photo, plan),
    );
    expect((composite.width, composite.height), (8, 10));
    final pixels = (await composite.toByteData())!;
    // Centre row keeps the original red; top band shows generated green.
    int red(int x, int y) => pixels.getUint8((y * 8 + x) * 4);
    int green(int x, int y) => pixels.getUint8((y * 8 + x) * 4 + 1);
    expect(red(4, 5), 255);
    expect(green(4, 5), 0);
    expect(green(4, 0), 255);
  });

  test('openai edits request: model, size, mask, and b64 result', () async {
    final result = await _png(2, 3, const ui.Color(0xFF0000FF));
    final adapter = _FakeAdapter(
      status: 200,
      body: utf8.encode(
        jsonEncode({
          'data': [
            {'b64_json': base64Encode(result)},
          ],
        }),
      ),
    );
    final service = OpenAiOutpaintService(
      'gms-key',
      baseUrl: 'https://gms.example/gmsapi/api.openai.com/',
      model: 'gpt-image-2',
      client: Dio()..httpClientAdapter = adapter,
    );
    final photo = await _png(8, 4, const ui.Color(0xFFFF0000));
    final out = await service.outpaint(
      image: photo,
      plan: const OutpaintPlan(left: 0, right: 0, up: 3, down: 3),
      prompt: 'stage',
    );
    expect(out, result);
    final request = adapter.request!;
    expect(
      request.uri.toString(),
      'https://gms.example/gmsapi/api.openai.com/v1/images/edits',
    );
    expect(request.headers['authorization'], 'Bearer gms-key');
    final form = request.data as FormData;
    final fields = {for (final f in form.fields) f.key: f.value};
    expect(fields['model'], 'gpt-image-2');
    expect(fields['size'], '1024x1536');
    expect(fields['prompt'], 'stage');
    expect(form.files.map((f) => f.key).toSet(), {'image', 'mask'});
  });

  test('gemini request: header, url and inline image parsing', () async {
    final result = await _png(2, 3, const ui.Color(0xFF0000FF));
    final adapter = _FakeAdapter(
      status: 200,
      body: utf8.encode(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'done'},
                  {
                    'inlineData': {
                      'mimeType': 'image/png',
                      'data': base64Encode(result),
                    },
                  },
                ],
              },
            },
          ],
        }),
      ),
    );
    final service = GeminiOutpaintService(
      'gms-key',
      baseUrl: 'https://gms.example/gmsapi/generativelanguage.googleapis.com',
      client: Dio()..httpClientAdapter = adapter,
    );
    final photo = await _png(8, 4, const ui.Color(0xFFFF0000));
    final out = await service.outpaint(
      image: photo,
      plan: const OutpaintPlan(left: 0, right: 0, up: 3, down: 3),
      prompt: 'stage',
    );
    expect(out, result);
    final request = adapter.request!;
    expect(
      request.uri.toString(),
      'https://gms.example/gmsapi/generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent',
    );
    expect(request.headers['x-goog-api-key'], 'gms-key');
    final body = request.data as Map;
    final parts = body['contents'][0]['parts'] as List;
    expect(parts.first['text'], contains('stage'));
    expect(parts.last['inline_data']['mime_type'], 'image/png');
  });

  test(
    'errors map to Korean ApiException; factory picks providers',
    () async {
      final service = OpenAiOutpaintService(
        'k',
        client: Dio()
          ..httpClientAdapter = _FakeAdapter(
            status: 402,
            body: utf8.encode('{"error":{"message":"no credit"}}'),
          ),
      );
      final photo = await _png(8, 4, const ui.Color(0xFFFF0000));
      expect(
        () => service.outpaint(
          image: photo,
          plan: const OutpaintPlan(left: 0, right: 0, up: 10, down: 10),
          prompt: 'x',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(
        outpaintServiceFor(
          provider: 'gemini',
          apiKey: 'k',
          baseUrl: '',
          model: '',
        ),
        isA<GeminiOutpaintService>(),
      );
      expect(
        outpaintServiceFor(
          provider: 'openai',
          apiKey: 'k',
          baseUrl: '',
          model: '',
        ),
        isA<OpenAiOutpaintService>(),
      );
      expect(
        outpaintServiceFor(
          provider: 'stability',
          apiKey: 'k',
          baseUrl: '',
          model: '',
        ),
        isA<StabilityOutpaintService>(),
      );
      expect(
        outpaintServiceFor(
          provider: 'openai',
          apiKey: '',
          baseUrl: '',
          model: '',
        ).available,
        false,
      );
    },
  );
}
