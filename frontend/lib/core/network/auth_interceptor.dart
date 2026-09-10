import 'package:dio/dio.dart';

/// 로그인 상태면 요청에 액세스 토큰을 붙이고, 서버가 401 을 주면 알려주는
/// dio 인터셉터.
///
/// 세션을 직접 알지 않고 함수 두 개만 받는다. 공통 모듈(core)이 인증 기능
/// 폴더에 기대면 의존 방향이 거꾸로 되기 때문이다. 앱은 [accessToken] 에
/// "세션의 토큰을 돌려주는 함수" 를, [onUnauthorized] 에 "세션을 비우는 함수" 를
/// 넣어 준다.
///
/// [publicPathPrefix] 아래 주소(로그인·가입·인증번호·중복 확인)에는 토큰을 붙이지
/// 않는다. 서버는 토큰이 붙어 있으면 **공개 API 라도 토큰을 먼저 검사**해서,
/// 만료된 토큰이 로그인 요청에 붙으면 로그인 자체가 401 로 막힌다(배포 서버에서
/// 확인). 로그아웃 뒤 다시 로그인하는 흐름이 바로 이 경우다.
///
/// 401 은 "지금 토큰이 더는 안 통한다" 는 뜻이다. 재발급 API 가 아직 없어
/// [onUnauthorized] 로 로그아웃 상태로 돌리는 데까지만 한다. 재발급 API 가
/// 생기면 여기서 재발급을 시도하고 실패할 때만 알리도록 바꾼다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.accessToken,
    required this.onUnauthorized,
    this.publicPathPrefix = '/api/v1/auth/',
  });

  /// 지금 액세스 토큰. 로그인 상태가 아니면 null.
  final String? Function() accessToken;

  /// 서버가 401 을 줬을 때.
  final void Function() onUnauthorized;

  /// 토큰을 붙이지 않는 주소의 앞부분.
  final String publicPathPrefix;

  static const authorizationHeader = 'Authorization';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = accessToken();
    // options.path 는 상대 주소일 수도 절대 주소일 수도 있어 uri 로 풀어서 본다.
    final isPublic = options.uri.path.startsWith(publicPathPrefix);
    if (token != null && !isPublic) {
      options.headers[authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) onUnauthorized();
    handler.next(err);
  }
}
