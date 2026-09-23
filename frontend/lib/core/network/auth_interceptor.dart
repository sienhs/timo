import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 요청에 액세스 토큰을 붙이고, 만료되면 조용히 재발급받아 요청을 이어가는
/// dio 인터셉터. [publicPathPrefix] 아래 공개 주소에는 토큰을 붙이지 않는다.
/// 401 처리: 공개 주소면 그냥 흘려보낸다 · `TOKEN_INVALID`·`REFRESH_REUSED` 는
/// 재발급 없이 바로 로그아웃(안 그러면 무한 재발급) · 이미 재시도한 요청이면
/// 로그아웃 · 그 외에는 재발급 뒤 새 토큰으로 다시 보내고 그 응답을 돌려준다.
/// 동시에 여럿 막혀도 재발급은 [_reissuing] 하나만 나가고 결과를 같이 받는다.
/// 로컬 백엔드는 요청자를 `X-Member-Id` 헤더로 정하므로 [sendMemberIdHeader] 가
/// 참이면(기본은 디버그 빌드만) 회원 번호도 같이 보낸다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.accessToken,
    required this.onUnauthorized,
    required this.reissue,
    this.memberId,
    this.sendMemberIdHeader = kDebugMode,
    this.publicPathPrefix = '/api/v1/auth/',
  });

  /// 재시도를 보낼 클라이언트. 이 인터셉터가 꽂혀 있는 바로 그 dio 여야
  /// 재시도가 사슬을 다시 타서 [onRequest] 가 새 토큰을 붙여 준다.
  final Dio dio;

  /// 지금 액세스 토큰. 로그인 상태가 아니면 null.
  final String? Function() accessToken;

  /// 서버가 401 을 줬고 재발급으로도 살릴 수 없을 때.
  final void Function() onUnauthorized;

  /// 재발급을 한 번 시도한다. 새 토큰이 세션에 들어갔으면 참. 리프레시 토큰이
  /// 없거나 서버가 거절했거나 그사이 로그아웃했으면 거짓.
  final Future<bool> Function() reissue;

  /// 지금 로그인한 회원 번호. 로그인 상태가 아니면 null. [sendMemberIdHeader] 가
  /// 참일 때만 쓴다.
  final int? Function()? memberId;

  /// 로컬 백엔드가 읽는 회원 번호 헤더를 붙일지.
  final bool sendMemberIdHeader;

  /// 토큰을 붙이지 않는 주소의 앞부분.
  final String publicPathPrefix;

  static const authorizationHeader = 'Authorization';

  /// 백엔드 `MockCurrentMemberProvider.MEMBER_ID_HEADER` 와 이름이 같다.
  static const memberIdHeader = 'X-Member-Id';

  /// 재발급 뒤 다시 보낸 요청이라는 표시. 이 요청이 또 401 이면 재발급을
  /// 되풀이하지 않는다.
  static const retriedKey = 'auth.retried';

  /// 진행 중인 재발급. 없으면 null.
  Future<bool>? _reissuing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = accessToken();
    if (token != null && !_isPublic(options)) {
      options.headers[authorizationHeader] = 'Bearer $token';
      final id = sendMemberIdHeader ? memberId?.call() : null;
      if (id != null) options.headers[memberIdHeader] = id.toString();
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_canRetry(err)) {
      // 살릴 수 없는 401 이면 로그아웃시킨다. 공개 주소의 401 은 [reissue] 가
      // 거짓을 돌려주는 것으로 이미 처리되므로 여기서 다루지 않는다.
      if (_isUnauthorized(err) && !_isPublic(err.requestOptions)) {
        onUnauthorized();
      }
      handler.next(err);
      return;
    }

    if (!await _reissueOnce()) {
      onUnauthorized();
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _retry(err.requestOptions));
    } on DioException catch (e) {
      // 재시도가 또 401 이면 이 사슬을 다시 타고 들어와 위에서 로그아웃까지
      // 처리된다. retriedKey 덕분에 재발급은 되풀이되지 않는다.
      handler.next(e);
    }
  }

  /// 재발급을 시도해 볼 만한 401 인지.
  bool _canRetry(DioException err) {
    if (!_isUnauthorized(err)) return false;
    if (_isPublic(err.requestOptions)) return false;
    if (err.requestOptions.extra[retriedKey] == true) return false;
    return !_isHopeless(err);
  }

  bool _isUnauthorized(DioException err) => err.response?.statusCode == 401;

  /// 주소가 공개 API 인지. `options.path` 는 상대 주소일 수도 절대 주소일 수도
  /// 있어 uri 로 풀어서 본다.
  bool _isPublic(RequestOptions options) =>
      options.uri.path.startsWith(publicPathPrefix);

  /// 재발급해 봐야 소용없는 이유인지. 자바 클래스 이름 대신 인증 실패에만
  /// 실리는 `errorCode` 를 본다. 이 판단이 어긋나면 무한 재발급이 된다.
  bool _isHopeless(DioException err) {
    final data = err.response?.data;
    if (data is! Map<String, dynamic>) return false;
    return _hopelessErrorCodes.contains(data['errorCode']);
  }

  /// 재발급으로 살릴 수 없는 401 의 `errorCode`. 위조·폐기된 토큰과 재사용된
  /// 리프레시 토큰. 백엔드 `AuthErrorCode` 이름과 같아야 한다.
  static const _hopelessErrorCodes = {'TOKEN_INVALID', 'REFRESH_REUSED'};

  /// 재발급을 시작하거나, 이미 진행 중이면 그 결과를 같이 기다린다.
  Future<bool> _reissueOnce() =>
      _reissuing ??= reissue().whenComplete(() => _reissuing = null);

  /// 실패했던 요청을 새 토큰으로 다시 보낸다. 인터셉터 사슬을 다시 타므로
  /// [onRequest] 가 헤더의 옛 토큰을 새 토큰으로 덮어쓴다.
  Future<Response<dynamic>> _retry(RequestOptions options) {
    options.extra[retriedKey] = true;
    return dio.fetch<dynamic>(options);
  }
}
