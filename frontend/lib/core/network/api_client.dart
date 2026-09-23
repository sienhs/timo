import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 앱 전체가 공유하는 HTTP 클라이언트.
/// 서버 주소·타임아웃·공통 설정은 여기서만 정한다.
class ApiClient {
  ApiClient._();

  /// 기본값은 로컬에서 띄운 백엔드다. 배포 서버로 붙일 때는 실행 인자로 바꾼다.
  ///   flutter run --dart-define=API_BASE_URL=https://<배포 도메인>
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static final Dio dio = _createDio();

  /// 서버가 준 이미지 주소를 앱이 읽을 수 있는 절대 주소로 바꾼다. 백엔드는
  /// 저장소 key(`poster/xxx.gif`)만 주고 호스트가 빠져 있어 그대로는 못 읽는다.
  /// 이미 절대 주소면 [Uri.resolve] 가 그대로 돌려주므로 S3 로 바뀌어도 된다.
  static String? imageUrl(String? key) => key == null || key.isEmpty
      ? null
      : Uri.parse(_baseUrl).resolve(key).toString();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // 요청·응답 로그는 개발 중에만 붙인다. 릴리즈에 남기면 응답 본문에 든
    // 개인정보가 로그로 샌다.
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          // 안드로이드 로그캣은 긴 줄을 잘라먹어서 debugPrint 를 쓴다.
          logPrint: (log) => debugPrint(log.toString()),
        ),
      );
    }

    return dio;
  }
}
