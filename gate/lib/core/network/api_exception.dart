import 'package:dio/dio.dart';

/// 네트워크 실패를 화면이 쓸 수 있는 형태로 번역한 예외.
/// data 계층 밖으로는 DioException 이 아니라 항상 이것만 나간다.
///
/// 팬 앱의 같은 클래스에서 게이트 앱에 필요한 만큼만 가져왔다. 백엔드는
/// ProblemDetail(RFC 9457) 형식으로 오류를 준다.
class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.errorCode});

  factory ApiException.from(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException('서버 응답이 늦어지고 있어요. 다시 스캔해주세요.');
      case DioExceptionType.connectionError:
        return const ApiException('인터넷 연결을 확인해주세요.');
      case DioExceptionType.badResponse:
        return ApiException._fromProblemDetail(e.response);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const ApiException('요청에 실패했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  factory ApiException._fromProblemDetail(Response<dynamic>? response) {
    final status = response?.statusCode;
    final data = response?.data;
    final fallback = '요청에 실패했어요. (오류 코드 $status)';

    // 프록시·게이트웨이가 대신 낸 오류는 우리 포맷이 아니라 HTML 일 수 있다.
    if (data is! Map<String, dynamic>) {
      return ApiException(fallback, status: status);
    }

    return ApiException(
      data['errorMessage'] as String? ?? fallback,
      status: status,
      errorCode: data['errorCode'] as String?,
    );
  }

  /// 사용자에게 그대로 보여줄 문구.
  final String message;

  /// HTTP 상태 코드. 서버 응답이 없는 실패(타임아웃 등)면 null.
  final int? status;

  /// 서버가 실어 주는 안 바뀌는 식별자(ProblemDetail 의 `errorCode`).
  final String? errorCode;

  @override
  String toString() => 'ApiException($status): $message';
}
