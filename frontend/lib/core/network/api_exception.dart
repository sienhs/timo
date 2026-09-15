import 'package:dio/dio.dart';

/// 네트워크 실패를 화면이 쓸 수 있는 형태로 번역한 예외.
/// repository 밖으로는 DioException 이 아니라 항상 이것만 나간다.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.status,
    this.errorCode,
    this.exceptionName,
    this.fieldErrors,
  });

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
      errorCode: data['errorCode'] as String?,
      exceptionName: data['exception'] as String?,
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

  /// 인증 실패의 이유를 나타내는 안 바뀌는 식별자(ProblemDetail 의 `errorCode`).
  /// `TOKEN_EXPIRED`, `TOKEN_INVALID` 처럼 온다.
  ///
  /// **인증 응답에만 붙는다.** 백엔드가 인증 전용 처리기에서만 실어 주기 때문에
  /// 공연·좌석 같은 다른 도메인의 실패에는 없다(null).
  ///
  /// [exceptionName] 과 역할이 겹쳐 보이지만 쓰임이 다르다. 저쪽은 자바 클래스
  /// 이름이라 백엔드가 클래스를 옮기거나 이름을 바꾸면 조용히 어긋난다. 이건
  /// 그러라고 따로 만든 값이라 안 바뀐다. **만료된 토큰인지 못 쓰는 토큰인지를
  /// 가르는 판단은 반드시 이걸로 한다** — 401 을 받고 재발급을 시도할지 바로
  /// 로그아웃할지가 여기서 갈리고, 잘못 가르면 재발급이 무한히 반복된다.
  final String? errorCode;

  /// 서버가 던진 예외의 클래스 이름(ProblemDetail 의 `exception`). 우리 포맷이
  /// 아닌 응답이나 서버에 닿지 못한 실패면 null.
  ///
  /// 같은 상태 코드 안에서 원인을 가를 때 쓴다. 가입 요청의 409 는 아이디·
  /// 닉네임·전화번호 중복 셋 중 하나인데, 문구로 비교하면 서버가 문구를 다듬을
  /// 때 깨지므로 이름으로 비교한다. 이름 값은 백엔드 예외 클래스명과 같다.
  final String? exceptionName;

  /// 회원가입 검증 실패(400)일 때만 온다. 필드명 → 사유.
  final Map<String, String>? fieldErrors;

  @override
  String toString() => 'ApiException($status): $message';
}
