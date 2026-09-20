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

  /// 서버가 준 이미지 key 를 브라우저·이미지 위젯이 열 수 있는 주소로 바꾼다.
  /// 없거나 빈 값이면 null 이라 부르는 쪽이 대체 자리를 그린다.
  ///
  /// 공연 목록 응답의 포스터가 `poster/xxx.png` 처럼 저장소 key 로만 온다.
  /// 그대로 쓰면 한 장도 안 뜨므로 여기서 한 번에 [baseUrl] 을 붙인다
  /// (팬 앱 `ApiClient.imageUrl` 과 같은 이유·같은 구현).
  static String? imageUrl(String? key) => key == null || key.isEmpty
      ? null
      : Uri.parse(baseUrl).resolve(key).toString();

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
