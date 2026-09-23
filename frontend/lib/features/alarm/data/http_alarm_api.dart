import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/alarm_status.dart';
import 'alarm_api.dart';

/// 백엔드 알림 신청 API 에 실제로 요청하는 [AlarmApi].
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 서버 주소·시간
/// 제한·로그는 [ApiClient] 가, 실패 응답을 화면용 문구로 바꾸는 일은
/// [ApiException] 이 맡는다. `HttpFavoriteApi` 와 같은 짜임이다.
///
/// 신청·해제는 본문 없이 204 만 온다. 켜졌는지는 누른 화면이 이미 안다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpAlarmApi implements AlarmApi {
  HttpAlarmApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const alarmsPath = '/api/v1/alarms';

  final Dio _dio;

  @override
  Future<AlarmStatus> fetchStatus(int concertId) async {
    final response = await _guard(
      () => _dio.get<dynamic>('$alarmsPath/$concertId'),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        AlarmStrings.unreadableResponse,
        status: response.statusCode,
      );
    }
    return AlarmStatus.fromJson(data);
  }

  @override
  Future<void> subscribe(int concertId, AlarmType type) async {
    await _guard(
      () => _dio.put<void>('$alarmsPath/$concertId/${type.serverName}'),
    );
  }

  @override
  Future<void> unsubscribe(int concertId, AlarmType type) async {
    await _guard(
      () => _dio.delete<void>('$alarmsPath/$concertId/${type.serverName}'),
    );
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
