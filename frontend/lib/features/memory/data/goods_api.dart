import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/goods_record.dart';
import '../models/ticket_effect.dart';

/// 소장품 서버 API.
///
/// 만들기는 두 번에 나눠 부른다 — 이미지를 먼저 올려 저장소 key 를 받고
/// ([uploadImages]), 그 key 를 써넣은 JSON 으로 생성한다([create]). 서버가 한
/// 요청으로 받지 않는 이유는 인물 레이어 이미지 장수가 정해져 있지 않아서다
/// (백엔드 `GoodsImageApi`). 덕분에 재전송이 이미지를 다시 올리지 않는다.
///
/// 조회는 목록([fetchMyGoods])과 상세([fetchDetail])뿐이다. **수정·삭제는
/// 없다** — 확정한 소장품은 서버에서도 바뀌지 않는다.
abstract interface class GoodsApi {
  /// 이미지 여러 장을 한 번에 올리고 **올린 순서대로** 저장소 key 를 받는다.
  ///
  /// 입장을 마친 내 티켓이어야 한다. 아니면 서버가 거절하고 저장소에는 아무것도
  /// 남지 않는다.
  Future<List<String>> uploadImages({
    required String ticketId,
    required List<String> paths,
  });

  /// 소장품 생성. [body] 는 [uploadImages] 가 준 key 를 채워 넣은 것이다.
  ///
  /// 멱등이다. 같은 `clientGoodsId` 로 다시 보내면 새로 만들지 않고 이미 만든
  /// 소장품이 그대로 온다 — 응답이 오다 끊긴 뒤 다시 눌러도 안전하다.
  Future<GoodsDetail> create({
    required String ticketId,
    required Map<String, dynamic> body,
  });

  /// 내 소장품 목록, 최신 순.
  Future<List<GoodsSummary>> fetchMyGoods();

  /// 소장품 하나의 전부. 다른 기기에서 복원할 때 쓴다.
  Future<GoodsDetail> fetchDetail(String goodsId);
}

/// 백엔드에 실제로 요청하는 구현.
///
/// 주소가 둘로 갈린다. 만들기는 티켓 아래(`/tickets/{id}/goods`), 조회는 굿즈
/// 아래(`/goods`)다 — 소장품은 티켓 한 장에 하나씩 붙어서 만들 때의 주어는
/// 티켓이고, 만든 뒤의 주어는 소장품이다(백엔드 `GoodsCreateApi`).
class HttpGoodsApi implements GoodsApi {
  HttpGoodsApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const ticketsPath = '/api/v1/tickets';
  static const goodsPath = '/api/v1/goods';

  final Dio _dio;

  @override
  Future<List<String>> uploadImages({
    required String ticketId,
    required List<String> paths,
  }) async {
    if (paths.isEmpty) return const [];

    final form = FormData();
    for (final path in paths) {
      form.files.add(
        MapEntry(
          'files',
          await MultipartFile.fromFile(path, filename: _filename(path)),
        ),
      );
    }

    final response = await _guard(
      () => _dio.post<dynamic>(
        '$ticketsPath/$ticketId/goods/images',
        data: form,
        options: Options(
          sendTimeout: GoodsConstants.transferTimeout,
          receiveTimeout: GoodsConstants.transferTimeout,
        ),
      ),
    );

    final body = response.data;
    if (body is! List) throw _unreadable(response);
    final keys = [
      for (final item in body.whereType<Map<String, dynamic>>())
        if (item['key'] is String) item['key'] as String,
    ];

    // 한 장이라도 빠지면 어느 자리의 key 가 빠졌는지 알 수 없다. 순서로 짝을
    // 맞추기 때문이다 — 어긋난 key 로 만들면 엉뚱한 이미지가 박힌 소장품이 된다.
    if (keys.length != paths.length) throw _unreadable(response);
    return keys;
  }

  @override
  Future<GoodsDetail> create({
    required String ticketId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _guard(
      () => _dio.post<dynamic>('$ticketsPath/$ticketId/goods', data: body),
    );
    return GoodsDetail.fromJson(_object(response));
  }

  @override
  Future<List<GoodsSummary>> fetchMyGoods() async {
    final response = await _guard(
      () => _dio.get<dynamic>(
        '$goodsPath/me',
        queryParameters: {'size': GoodsConstants.pageSize},
      ),
    );

    // 목록 응답은 Spring 의 `PagedModel` 이라 항목이 `content` 안에 있다.
    final content = _object(response)['content'];
    if (content is! List) throw _unreadable(response);
    return content
        .whereType<Map<String, dynamic>>()
        .map(GoodsSummary.fromJson)
        .toList();
  }

  @override
  Future<GoodsDetail> fetchDetail(String goodsId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$goodsPath/$goodsId'),
    );
    return GoodsDetail.fromJson(_object(response));
  }

  /// 보낼 파일명. 서버는 이 이름으로 저장하지 않지만(key 는 서버가 만든다)
  /// 확장자로 형식을 가리므로 원래 이름을 그대로 넘긴다.
  static String _filename(String path) => path.split(RegExp(r'[\\/]')).last;

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  /// `HttpTicketApi` 등 다른 도메인의 같은 이름 함수와 같은 일을 한다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  Map<String, dynamic> _object(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw _unreadable(response);
  }

  ApiException _unreadable(Response<dynamic> response) =>
      ApiException(GoodsText.unreadableResponse, status: response.statusCode);
}

/// 서버 없이 도는 구현. 위젯 테스트와 데모가 쓴다.
///
/// 올린 척하고 만든 척한다 — 이미지는 기기 경로를 그대로 key 로 삼고, 만든
/// 소장품은 이 객체가 들고 있다가 목록·상세로 돌려준다. 멱등도 흉내 낸다.
class MockGoodsApi implements GoodsApi {
  final _byTicket = <String, GoodsDetail>{};
  var _nextId = 1;

  @override
  Future<List<String>> uploadImages({
    required String ticketId,
    required List<String> paths,
  }) async => [for (final path in paths) 'mock/$ticketId/$path'];

  @override
  Future<GoodsDetail> create({
    required String ticketId,
    required Map<String, dynamic> body,
  }) async {
    final made = _byTicket[ticketId];
    if (made != null) return made;

    final detail = GoodsDetail(
      goodsId: '${_nextId++}',
      ticketId: ticketId,
      concertId: '',
      clientGoodsId: body['clientGoodsId'] as String? ?? '',
      effect: TicketEffect.fromWire(body['effectType'] as String?),
      snapshot: const ConcertSnapshot(),
      personLayers: const [],
      backgroundUrl: body['backgroundKey'] as String?,
      previewUrl: body['previewKey'] as String?,
    );
    _byTicket[ticketId] = detail;
    return detail;
  }

  @override
  Future<List<GoodsSummary>> fetchMyGoods() async => [
    for (final detail in _byTicket.values)
      GoodsSummary(
        goodsId: detail.goodsId,
        ticketId: detail.ticketId,
        effect: detail.effect,
        snapshot: detail.snapshot,
        previewUrl: detail.previewUrl,
      ),
  ];

  @override
  Future<GoodsDetail> fetchDetail(String goodsId) async =>
      _byTicket.values.firstWhere(
        (detail) => detail.goodsId == goodsId,
        orElse: () => throw const ApiException(GoodsText.restoreFailed),
      );
}
