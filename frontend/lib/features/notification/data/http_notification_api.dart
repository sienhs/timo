import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/notification_page.dart';
import 'notification_api.dart';

/// 백엔드 알림함 API(`/api/v1/notifications`)에 실제로 요청하는 [NotificationApi].
///
/// 어느 주소에 무엇을 보내고 응답에서 무엇을 꺼내는지만 안다. 토큰을 붙이는 일은
/// `AuthInterceptor` 가, 서버 주소·시간 제한·로그는 [ApiClient] 가, 실패 응답을
/// 화면용 문구로 바꾸는 일은 [ApiException] 이 맡는다.
///
/// [dio] 는 테스트를 위해 받는다. 앱에서는 넘기지 않아 [ApiClient.dio] 를 쓴다.
class HttpNotificationApi implements NotificationApi {
  HttpNotificationApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const basePath = '/api/v1/notifications';
  static const unreadCountPath = '$basePath/unread-count';
  static const readAllPath = '$basePath/read-all';

  /// 한 번에 받아 올 개수. 서버가 허용하는 범위는 1~50 이고 기본값도 20 이다.
  /// 그래도 적어 보내는 것은 앱이 몇 개 단위로 이어 받는지가 화면 쪽 결정이라서다.
  static const pageSize = 20;

  final Dio _dio;

  @override
  Future<NotificationPage> fetchNotifications({int? cursor}) async {
    final response = await _guard(
      () => _dio.get<dynamic>(
        basePath,
        // 커서가 없으면 아예 안 싣는다. 빈 값을 실으면 서버가 형식 오류로 400 이다.
        queryParameters: {'size': pageSize, 'cursor': ?cursor},
      ),
    );
    return NotificationPage.fromJson(_body(response));
  }

  @override
  Future<int> fetchUnreadCount() async {
    final response = await _guard(() => _dio.get<dynamic>(unreadCountPath));
    return (_body(response)['unreadCount'] as num?)?.toInt() ?? 0;
  }

  /// 없는 알림이나 남의 알림이면 서버가 404 를 주고 [ApiException] 이 된다.
  @override
  Future<void> markRead(int notificationId) async {
    await _guard(() => _dio.patch<dynamic>('$basePath/$notificationId/read'));
  }

  @override
  Future<void> markAllRead() async {
    await _guard(() => _dio.patch<dynamic>(readAllPath));
  }

  /// dio 실패를 [ApiException] 으로 바꿔 던진다. 모든 요청이 이걸 거친다.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 성공 응답 본문. JSON 객체가 아니면 화면용 예외로 바꿔서, 화면이 형 변환
  /// 오류 대신 안내 문구를 받게 한다.
  Map<String, dynamic> _body(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw ApiException(
      NotificationStrings.unreadableResponse,
      status: response.statusCode,
    );
  }
}
