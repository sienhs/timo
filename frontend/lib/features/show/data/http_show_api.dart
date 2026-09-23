import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/show_detail.dart';
import 'show_api.dart';

/// 백엔드 공연 API(v1)에 실제로 요청하는 [ShowApi]. 상세 응답이 구역별 가격
/// (`sectionPrices`)까지 주므로 요청 하나로 화면을 채우고 로그인 전에도 가격이 보인다.
/// 상세를 부를 때마다 서버가 조회수를 1 올린다 — 화면이 들어올 때 한 번만 부른다.
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpShowApi implements ShowApi {
  HttpShowApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const concertsPath = '/api/v1/concerts';

  final Dio _dio;

  @override
  Future<ShowDetail> fetchShowDetail(int concertId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$concertsPath/$concertId'),
    );
    return ShowDetail.fromJson(_body(response));
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
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
    ShowDetailStrings.unreadableResponse,
    status: response.statusCode,
  );
}
