import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';
import 'package:timo/features/memory/constants.dart';
import 'package:timo/features/memory/data/goods_api.dart';
import 'package:timo/features/memory/data/goods_failure.dart';
import 'package:timo/features/memory/models/ticket_effect.dart';

import '../../core/network/fake_http_adapter.dart';

/// 소장품 v1 API 에 맞는 요청이 나가고 응답을 제대로 읽는지. 서버 없이
/// [FakeHttpAdapter] 로 검사한다.
void main() {
  late FakeHttpAdapter adapter;
  late HttpGoodsApi api;

  void givenServer(FutureOr<ResponseBody> Function(RecordedRequest) handler) {
    adapter = FakeHttpAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://fake.test'))
      ..httpClientAdapter = adapter;
    api = HttpGoodsApi(dio: dio);
  }

  /// 서버 상세 응답 한 건. 실제 `GoodsDetailResponseDto` 모양이다.
  Map<String, dynamic> detailJson({int goodsId = 7}) => {
    'goodsId': goodsId,
    'ticketId': 1024,
    'concertId': 3,
    'clientGoodsId': '1024',
    'backgroundKey': 'goods/1/1024/a.png',
    'backgroundUrl': 'https://cdn.test/goods/1/1024/a.png',
    'effectType': 'laser',
    'backgroundFraming': null,
    'personLayers': [],
    'transitionConfig': {'brightness': 0.0},
    'renderMetadata': {'demoDepth': true},
    'concertSnapshot': {
      'title': '빛으로 남은 밤',
      'artist': null,
      'date': '2026-09-26T19:00:00',
      'venue': '서울 메모리 홀',
    },
    'createdAt': '2026-09-27T10:00:00',
  };

  group('uploadImages', () {
    late Directory dir;
    late List<String> files;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('timo_upload');
      files = [];
      for (final name in ['bg.png', 'depth.png']) {
        final file = File('${dir.path}/$name');
        await file.writeAsBytes([1, 2, 3]);
        files.add(file.path);
      }
    });

    tearDown(() => dir.delete(recursive: true));

    test('티켓 아래 주소로 multipart 를 보내고 올린 순서대로 key 를 받는다', () async {
      givenServer(
        (_) => jsonResponse([
          {'key': 'goods/1/1024/x.png', 'url': 'https://cdn.test/x.png'},
          {'key': 'goods/1/1024/y.png', 'url': 'https://cdn.test/y.png'},
        ], status: 201),
      );

      final keys = await api.uploadImages(ticketId: '1024', paths: files);

      expect(keys, ['goods/1/1024/x.png', 'goods/1/1024/y.png']);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/tickets/1024/goods/images');
      expect(request.options.contentType, startsWith('multipart/form-data'));
      // 파트 이름은 서버 규약(`files`)이고 두 장이 다 실렸다.
      expect(request.rawBody, contains('name="files"; filename="bg.png"'));
      expect(request.rawBody, contains('name="files"; filename="depth.png"'));
      // 이미지 전송은 공통 제한 시간보다 길게 잡는다.
      expect(request.options.receiveTimeout, GoodsConstants.transferTimeout);
    });

    test('올린 장수와 받은 key 수가 다르면 실패다', () async {
      // 순서로 짝을 맞추므로 하나가 빠지면 어느 자리인지 알 수 없다.
      givenServer(
        (_) => jsonResponse([
          {'key': 'only-one', 'url': 'u'},
        ], status: 201),
      );

      expect(
        () => api.uploadImages(ticketId: '1024', paths: files),
        throwsA(isA<ApiException>()),
      );
    });

    test('올릴 것이 없으면 요청도 없다', () async {
      givenServer((_) => throw StateError('요청이 나가면 안 된다'));

      expect(
        await api.uploadImages(ticketId: '1024', paths: const []),
        isEmpty,
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('create', () {
    test('티켓 아래 주소로 본문을 그대로 보내고 상세를 읽는다', () async {
      givenServer((_) => jsonResponse(detailJson(), status: 201));

      final detail = await api.create(
        ticketId: '1024',
        body: {'clientGoodsId': '1024', 'backgroundKey': 'k'},
      );

      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/api/v1/tickets/1024/goods');
      expect(request.jsonBody, {'clientGoodsId': '1024', 'backgroundKey': 'k'});

      expect(detail.goodsId, '7');
      expect(detail.ticketId, '1024');
      expect(detail.concertId, '3');
      expect(detail.effect, TicketEffect.laser);
      expect(detail.backgroundUrl, 'https://cdn.test/goods/1/1024/a.png');
      expect(detail.snapshot.title, '빛으로 남은 밤');
      // 아티스트 없는 공연은 null 이고, 뒷면에서는 그 줄이 빠진다.
      expect(detail.snapshot.artist, isNull);
      expect(detail.snapshot.details.keys, isNot(contains('아티스트')));
    });

    test('멱등 재전송의 200 도 같은 모양으로 읽는다', () async {
      givenServer((_) => jsonResponse(detailJson()));

      final detail = await api.create(ticketId: '1024', body: const {});

      expect(detail.goodsId, '7');
    });

    test('거절 이유는 예외 이름으로 갈라 앱 문구가 된다', () async {
      givenServer(
        (_) => problemResponse(
          status: 409,
          errorMessage: '이미 굿즈를 만든 티켓입니다. (ticketId=1024)',
          exception: 'GoodsAlreadyExistsException',
        ),
      );

      try {
        await api.create(ticketId: '1024', body: const {});
        fail('409 는 예외여야 한다');
      } on ApiException catch (e) {
        expect(e.status, 409);
        expect(e.exceptionName, 'GoodsAlreadyExistsException');
        expect(goodsFailureMessage(e), GoodsText.alreadyExists);
      }
    });

    test('모르는 이유는 서버 문구를 그대로 올린다', () {
      const unknown = ApiException(
        '알 수 없는 사정',
        status: 500,
        exceptionName: 'SomethingElseException',
      );
      expect(goodsFailureMessage(unknown), '알 수 없는 사정');
      // 서버 응답이 아닌 실패는 부른 쪽이 정한 문구다.
      expect(
        goodsFailureMessage(StateError('x'), fallback: GoodsText.restoreFailed),
        GoodsText.restoreFailed,
      );
    });
  });

  group('조회', () {
    test('내 목록은 PagedModel 의 content 를 읽는다', () async {
      givenServer(
        (_) => jsonResponse({
          'content': [
            {
              'goodsId': 7,
              'ticketId': 1024,
              'clientGoodsId': '1024',
              'previewUrl': 'https://cdn.test/p.jpg',
              'effectType': 'stageLights',
              'concertSnapshot': {'title': '빛으로 남은 밤'},
              'createdAt': '2026-09-27T10:00:00',
            },
          ],
          'page': {'size': 100, 'number': 0, 'totalElements': 1},
        }),
      );

      final goods = await api.fetchMyGoods();

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/api/v1/goods/me');
      expect(request.query['size'], '${GoodsConstants.pageSize}');

      expect(goods.single.goodsId, '7');
      expect(goods.single.ticketId, '1024');
      expect(goods.single.previewUrl, 'https://cdn.test/p.jpg');
      expect(goods.single.effect, TicketEffect.stageLights);
      expect(goods.single.snapshot.title, '빛으로 남은 밤');
    });

    test('상세는 소장품 번호로 받는다', () async {
      givenServer((_) => jsonResponse(detailJson(goodsId: 9)));

      final detail = await api.fetchDetail('9');

      expect(adapter.requests.single.path, '/api/v1/goods/9');
      expect(detail.goodsId, '9');
    });

    test('모르는 이펙트 이름은 효과 없음으로 읽는다', () {
      // 서버에 값이 하나 늘었다고 소장품이 안 열릴 이유는 없다.
      expect(TicketEffect.fromWire('hologram'), TicketEffect.none);
      expect(TicketEffect.fromWire(null), TicketEffect.none);
      expect(TicketEffect.fromWire('godRays'), TicketEffect.godRays);
    });
  });
}
