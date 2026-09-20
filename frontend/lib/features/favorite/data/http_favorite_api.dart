import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/favorite_show.dart';
import 'favorite_api.dart';

/// 백엔드 찜 API 에 실제로 요청하는 [FavoriteApi].
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다. `HttpHomeApi` · `HttpShowApi` 와 같은 짜임이다.
///
/// 등록·해제는 본문 없이 204 만 온다. 그래서 응답에서 꺼낼 것이 없다 — 찜한
/// 뒤의 목록은 화면이 이미 알고 있고(누른 그 공연), 서버와 어긋났는지는 다음에
/// [fetchShows] 할 때 맞춰진다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpFavoriteApi implements FavoriteApi {
  HttpFavoriteApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const wishesPath = '/api/v1/wishes';

  final Dio _dio;

  @override
  Future<List<FavoriteShow>> fetchShows() async {
    final response = await _guard(
      () => _dio.get<dynamic>(
        '$wishesPath/me',
        queryParameters: {'size': FavoriteLimits.showPageSize},
      ),
    );
    // 목록 응답은 Spring 의 `PagedModel` 이라 배열이 `content` 안에 있다.
    final content = _body(response)['content'];
    if (content is! List) throw _unreadable(response);
    return content
        .whereType<Map<String, dynamic>>()
        .map(FavoriteShow.fromConcertSummaryJson)
        .toList();
  }

  @override
  Future<void> addShow(int concertId) async {
    await _guard(() => _dio.put<void>('$wishesPath/$concertId'));
  }

  @override
  Future<void> removeShow(int concertId) async {
    await _guard(() => _dio.delete<void>('$wishesPath/$concertId'));
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  ///
  /// `HttpHomeApi` · `HttpShowApi` 등과 같다. 같은 코드가 여럿이라 `core/network`
  /// 로 올릴 때가 됐다는 메모가 그쪽에 이미 있다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면(프록시가 HTML 을 준 경우 등) 화면용
  /// 예외로 바꿔서, 화면이 형 변환 오류 대신 안내 문구를 받게 한다.
  Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw _unreadable(response);
  }

  ApiException _unreadable(Response<dynamic> response) => ApiException(
    FavoriteStrings.unreadableResponse,
    status: response.statusCode,
  );
}
