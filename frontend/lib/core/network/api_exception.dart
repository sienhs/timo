import 'package:dio/dio.dart';

/// 네트워크 실패를 화면이 쓸 수 있는 형태로 번역한 예외.
/// repository 밖으로는 DioException 이 아니라 항상 이것만 나간다.
class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.fieldErrors});

  /// DioException 을 받아 실패 종류별로 사용자 문구로 번역한다.
  factory ApiException.from(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException('서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해주세요.');
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

  /// 서버가 내려준 ProblemDetail(RFC 9457) 본문에서 화면에 쓸 값을 꺼낸다.
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
      fieldErrors: _fieldErrorsOf(data['errors']),
    );
  }

  /// 검증 실패(400)일 때만 붙는 errors 배열을 필드명 → 사유 맵으로 바꾼다.
  static Map<String, String>? _fieldErrorsOf(Object? errors) {
    if (errors is! List) return null;

    final result = {
      for (final error in errors.whereType<Map<String, dynamic>>())
        if (error['field'] is String && error['reason'] is String)
          error['field'] as String: error['reason'] as String,
    };

    return result.isEmpty ? null : result;
  }

  /// 사용자에게 그대로 보여줄 문구.
  final String message;

  /// HTTP 상태 코드. 서버 응답이 없는 실패(타임아웃 등)면 null.
  final int? status;

  /// 회원가입 검증 실패(400)일 때만 온다. 필드명 → 사유.
  final Map<String, String>? fieldErrors;

  @override
  String toString() => 'ApiException($status): $message';
}
