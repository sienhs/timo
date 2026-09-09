import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timo/core/network/api_exception.dart';

/// 네트워크 실패 번역.
///
/// 서버 없이 검증할 수 있는 부분이라 지금 굳혀 둔다. 백엔드가 내려주는
/// ProblemDetail 의 실제 모양(errorMessage, errors)을 그대로 재현해,
/// 포맷이 바뀌면 이 테스트가 먼저 깨지게 한다.
void main() {
  /// 서버가 에러 응답을 내려준 상황.
  DioException badResponse(Object? body, {int status = 400}) {
    final options = RequestOptions(path: '/api/v1/auth/signup');
    return DioException(
      type: DioExceptionType.badResponse,
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    );
  }

  /// 서버까지 닿지 못한 상황. 응답이 없다.
  DioException failure(DioExceptionType type) => DioException(
    type: type,
    requestOptions: RequestOptions(path: '/api/v1/concerts'),
  );

  group('ProblemDetail 응답', () {
    test('errorMessage 를 사용자 문구로 쓴다', () {
      final result = ApiException.from(
        badResponse({
          'type': 'about:blank',
          'title': 'Bad Request',
          'status': 400,
          'errorMessage': '이미 사용 중인 아이디예요.',
          'timestamp': '2026-09-09 15:56:25',
          'exception': 'DuplicateUsernameException',
        }),
      );

      expect(result.message, '이미 사용 중인 아이디예요.');
      expect(result.status, 400);
      expect(result.exceptionName, 'DuplicateUsernameException');
      expect(result.fieldErrors, isNull);
    });

    test('errors 배열을 필드명 → 사유 맵으로 바꾼다', () {
      final result = ApiException.from(
        badResponse({
          'status': 400,
          'errorMessage': '입력값이 올바르지 않습니다.',
          'errors': [
            {'field': 'password', 'reason': '8자 이상이어야 합니다.'},
            {'field': 'nickname', 'reason': '필수 입력값입니다.'},
          ],
        }),
      );

      expect(result.fieldErrors, {
        'password': '8자 이상이어야 합니다.',
        'nickname': '필수 입력값입니다.',
      });
    });

    test('본문이 우리 포맷이 아니면 상태 코드로 대체한다', () {
      // 프록시가 대신 낸 502 는 HTML 이 온다.
      final result = ApiException.from(
        badResponse('<html>Bad Gateway</html>', status: 502),
      );

      expect(result.message, contains('502'));
      expect(result.status, 502);
      expect(result.exceptionName, isNull);
    });
  });

  group('서버에 닿지 못한 실패', () {
    test('연결이 끊기면 인터넷 확인을 안내한다', () {
      final result = ApiException.from(
        failure(DioExceptionType.connectionError),
      );

      expect(result.message, '인터넷 연결을 확인해주세요.');
      expect(result.status, isNull);
    });

    test('타임아웃이면 응답 지연을 안내한다', () {
      final result = ApiException.from(
        failure(DioExceptionType.receiveTimeout),
      );

      expect(result.message, contains('늦어지고'));
      expect(result.status, isNull);
    });
  });
}
