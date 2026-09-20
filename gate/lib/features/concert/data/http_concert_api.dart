import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/concert_summary.dart';
import 'concert_api.dart';

/// 백엔드 공연 목록 API(`GET /api/v1/concerts`)에 실제로 요청하는 [ConcertApi].
///
/// 이 주소는 **로그인 없이 열려 있다**(백엔드 SecurityConfig 의 permitAll).
/// 게이트를 위해 따로 만든 API 가 아니라 팬 앱이 쓰는 목록과 같은 것이다 —
/// 공연 이름·공연장·일시는 관람객에게도 공개되는 정보라 게이트 전용 주소를
/// 둘 이유가 없었다. 관리자 토큰은 어차피 AuthInterceptor 가 붙인다.
///
/// 응답은 Spring 의 `PagedModel` 이라 배열이 `content` 안에 있다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpConcertApi implements ConcertApi {
  HttpConcertApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  /// 백엔드 ConcertController.BASE_PATH.
  static const concertsPath = '/api/v1/concerts';

  final Dio _dio;

  @override
  Future<List<ConcertSummary>> findAll({String? keyword}) async {
    final trimmed = keyword?.trim();

    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        concertsPath,
        queryParameters: {
          'size': ConcertMetrics.pageSize,
          // 빈 검색어는 아예 빼서 보낸다. `keyword=` 로 보내도 서버가 무시해
          // 주지만, 보내지 않는 쪽이 "조건 없음" 이라는 뜻에 맞다.
          if (trimmed != null && trimmed.isNotEmpty) 'keyword': trimmed,
        },
      );
    } on DioException catch (e) {
      throw ApiException.from(e);
    }

    final body = response.data;
    // 프록시가 HTML 을 준 경우 등. 형 변환 오류 대신 안내 문구를 화면에 넘긴다.
    if (body is! Map<String, dynamic> || body['content'] is! List) {
      throw ApiException(
        '공연 목록을 읽을 수 없어요. 잠시 후 다시 시도해주세요.',
        status: response.statusCode,
      );
    }

    return (body['content'] as List)
        .whereType<Map<String, dynamic>>()
        .map(ConcertSummary.fromJson)
        .toList();
  }
}
