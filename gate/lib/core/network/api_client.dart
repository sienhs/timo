import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 앱 전체가 공유하는 HTTP 클라이언트. 서버 주소·타임아웃은 여기서만 정한다.
///
/// 팬 앱(`frontend/`)의 같은 파일과 규칙이 같다. 두 앱이 같은 백엔드에 붙으므로
/// 실행 인자 이름도 맞췄다.
class ApiClient {
  ApiClient._();

  /// 기본값은 로컬에서 띄운 백엔드다. 배포 서버로 붙일 때는 실행 인자로 바꾼다.
  ///   flutter run --dart-define=API_BASE_URL=https://<배포 도메인>
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static final Dio dio = _createDio();

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        // 검증 한 건은 3초 안에 끝나야 한다(요구사항). 그보다 오래 기다리면
        // 게이트 줄이 멈추므로 서버 응답도 그 근처에서 끊는다.
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    // 요청·응답 로그는 개발 중에만. 릴리즈에 남기면 응답 본문의 관람객 정보가 샌다.
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (log) => debugPrint(log.toString()),
        ),
      );
    }

    return dio;
  }
}
