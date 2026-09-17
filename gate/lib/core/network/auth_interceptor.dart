import 'package:dio/dio.dart';

/// 요청에 액세스 토큰을 붙이고, 토큰이 만료되면 조용히 재발급받아 요청을
/// 이어가는 dio 인터셉터. 팬 앱(`frontend/`)의 같은 파일과 규칙이 같다.
///
/// 세션을 직접 알지 않고 함수 몇 개만 받는다. 공통 모듈(core)이 인증 기능
/// 폴더에 기대면 의존 방향이 거꾸로 되기 때문이다. 앱은 [accessToken] 에
/// "세션의 토큰을 돌려주는 함수" 를, [reissue] 에 "재발급받아 세션에 넣는 함수"
/// 를, [onUnauthorized] 에 "세션을 비우는 함수" 를 넣어 준다.
///
/// [publicPathPrefix] 아래 주소(로그인·로그아웃·재발급)에는 토큰을 붙이지
/// 않는다. 서버는 토큰이 붙어 있으면 **공개 API 라도 토큰을 먼저 검사**해서,
/// 만료된 토큰이 로그인 요청에 붙으면 로그인 자체가 401 로 막힌다. 재발급도
/// 마찬가지다 — 재발급을 부르는 시점의 액세스 토큰은 이미 만료돼 있다.
///
/// ## 401 을 받으면
///
/// 1. 공개 주소에서 온 401 이면 그냥 흘려보낸다. 재발급 요청 자체가 거절당한
///    경우가 여기인데, 그건 [reissue] 가 거짓을 돌려주는 것으로 이미 처리된다.
/// 2. 이유가 "재발급해도 소용없음" 이면 재발급하지 않고 바로 로그아웃한다.
///    **이 판단이 없으면 무한 루프가 된다** — 위조된 토큰으로 재발급받아 봐야
///    새 토큰도 같은 이유로 막히고, 그걸 또 만료로 보고 재발급을 시도한다.
/// 3. 이미 한 번 재시도한 요청이면 또 시도하지 않고 로그아웃한다.
/// 4. 그 외에는 재발급을 시도한다. 성공하면 **실패했던 요청을 새 토큰으로 다시
///    보내고** 그 응답을 원래 호출자에게 성공으로 돌려준다. 화면은 만료가 있었는지
///    모른다. 실패하면 로그아웃시키고 원래 오류를 그대로 흘려보낸다.
///
/// ## 재발급은 한 번만 나간다
///
/// 요청 여럿이 동시에 만료로 막혀도 재발급은 진행 중인 하나([_reissuing])를
/// 같이 기다린다. 늦게 도착한 응답이 먼저 받은 토큰을 덮어쓰는 일을 막는다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.accessToken,
    required this.onUnauthorized,
    required this.reissue,
    this.publicPathPrefix = '/api/v1/auth/',
  });

  /// 재시도를 보낼 클라이언트. 이 인터셉터가 꽂혀 있는 바로 그 dio 여야 한다.
  ///
  /// 재시도를 인터셉터 사슬에 다시 태워야 [onRequest] 가 **새 토큰**을 붙여
  /// 주고, 그래도 401 이면 [onError] 가 다시 받아 로그아웃까지 갈 수 있다.
  final Dio dio;

  /// 지금 액세스 토큰. 로그인 상태가 아니면 null.
  final String? Function() accessToken;

  /// 서버가 401 을 줬고 재발급으로도 살릴 수 없을 때.
  final void Function() onUnauthorized;

  /// 재발급을 한 번 시도한다. 새 토큰이 세션에 들어갔으면 참.
  ///
  /// 거짓을 돌려주는 경우: 리프레시 토큰이 없거나, 서버가 거절했거나, 서버를
  /// 다녀오는 사이에 사용자가 로그아웃했거나. 어느 쪽이든 인터셉터가 할 일은
  /// 같아서 사유를 나누지 않는다.
  final Future<bool> Function() reissue;

  /// 토큰을 붙이지 않는 주소의 앞부분.
  final String publicPathPrefix;

  static const authorizationHeader = 'Authorization';

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
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_canRetry(err)) {
      // 살릴 수 없는 401 이면 로그아웃시킨다. 공개 주소의 401 은 여기서 다루지
      // 않는다(위 설명 1번).
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

  /// 재발급해 봐야 소용없는 이유인지.
  ///
  /// 서버가 인증 실패 응답에만 실어 주는 `errorCode` 를 본다. 백엔드
  /// `AuthErrorCode` 의 이름과 같아야 한다. 기능 폴더의 상수를 쓰지 않고 여기
  /// 두는 것은 공통 모듈이 인증 폴더에 기대지 않게 하기 위해서다.
  bool _isHopeless(DioException err) {
    final data = err.response?.data;
    if (data is! Map<String, dynamic>) return false;
    final errorCode = data['errorCode'];
    return errorCode == 'TOKEN_INVALID' || errorCode == 'REFRESH_REUSED';
  }

  /// 재발급을 시작하거나, 이미 진행 중이면 그 결과를 같이 기다린다.
  Future<bool> _reissueOnce() =>
      _reissuing ??= reissue().whenComplete(() => _reissuing = null);

  /// 실패했던 요청을 새 토큰으로 다시 보낸다.
  ///
  /// 인터셉터 사슬을 다시 타므로 [onRequest] 가 새 토큰을 붙여 준다. 헤더에 남은
  /// 옛 토큰은 거기서 덮어써진다.
  Future<Response<dynamic>> _retry(RequestOptions options) {
    options.extra[retriedKey] = true;
    return dio.fetch<dynamic>(options);
  }
}
