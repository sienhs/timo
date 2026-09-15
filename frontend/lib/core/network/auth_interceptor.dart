import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 요청에 액세스 토큰을 붙이고, 토큰이 만료되면 조용히 재발급받아 요청을
/// 이어가는 dio 인터셉터.
///
/// 세션을 직접 알지 않고 함수 몇 개만 받는다. 공통 모듈(core)이 인증 기능
/// 폴더에 기대면 의존 방향이 거꾸로 되기 때문이다. 앱은 [accessToken] 에
/// "세션의 토큰을 돌려주는 함수" 를, [reissue] 에 "재발급받아 세션에 넣는 함수"
/// 를, [onUnauthorized] 에 "세션을 비우는 함수" 를 넣어 준다.
///
/// [publicPathPrefix] 아래 주소(로그인·가입·인증번호·중복 확인·재발급)에는 토큰을
/// 붙이지 않는다. 서버는 토큰이 붙어 있으면 **공개 API 라도 토큰을 먼저 검사**해서,
/// 만료된 토큰이 로그인 요청에 붙으면 로그인 자체가 401 로 막힌다(배포 서버에서
/// 확인). 로그아웃 뒤 다시 로그인하는 흐름이 그 경우고, 재발급도 마찬가지다 —
/// 재발급을 부르는 시점의 액세스 토큰은 이미 만료돼 있다.
///
/// ## 401 을 받으면
///
/// 1. 공개 주소에서 온 401 이면 그냥 흘려보낸다. 재발급 요청 자체가 거절당한
///    경우가 여기인데, 그건 [reissue] 가 거짓을 돌려주는 것으로 이미 처리된다.
///    여기서 또 로그아웃시키면 같은 일이 두 번 일어난다.
/// 2. 이유가 "재발급해도 소용없음" 이면 재발급하지 않고 바로 로그아웃한다.
///    **이 판단이 없으면 무한 루프가 된다** — 위조된 토큰으로 재발급받아 봐야
///    새 토큰도 같은 이유로 막히고, 그걸 또 만료로 보고 재발급을 시도한다.
///    서버가 만료(`TOKEN_EXPIRED`)와 무효(`TOKEN_INVALID`)를 굳이 나눠 주는
///    이유가 이것이다.
/// 3. 이미 한 번 재시도한 요청이면 또 시도하지 않고 로그아웃한다. 2번을 빠져나온
///    경우(이유 코드가 없는 401 등)의 안전장치다.
/// 4. 그 외에는 재발급을 시도한다. 성공하면 **실패했던 요청을 새 토큰으로 다시
///    보내고** 그 응답을 원래 호출자에게 성공으로 돌려준다. 화면은 만료가 있었는지
///    모른다. 실패하면 로그아웃시키고 원래 오류를 그대로 흘려보낸다.
///
/// ## 재발급은 한 번만 나간다
///
/// 화면 하나가 요청을 동시에 여럿 보냈다가 전부 만료로 막히는 일이 흔하다.
/// 그대로 두면 재발급도 그만큼 나가 서버에 부담이고, 늦게 도착한 응답이 먼저
/// 받은 토큰을 덮어써 상태가 뒤엉킨다. 그래서 진행 중인 재발급 하나를 들고
/// 있다가([_reissuing]) 뒤에 온 요청들은 새로 시작하지 않고 그 결과를 같이
/// 받는다.
///
/// ## 로컬 백엔드용 회원 번호 헤더
///
/// 백엔드의 `local` 프로필은 요청자를 `X-Member-Id` 헤더로 정한다
/// (`MockCurrentMemberProvider`). 좌석 쪽은 토큰 기반으로 옮겨갔지만 **내 정보
/// 조회가 아직 이 헤더를 쓴다.** 없으면 마이페이지가 로컬에서 401 이다. 그래서
/// [sendMemberIdHeader] 가 참이면 토큰과 함께 회원 번호도 보낸다. 기본값은
/// 디버그 빌드에서만 참이다 — 배포 서버는 이 헤더를 보지 않지만, 클라이언트가
/// 주장하는 신원을 릴리스 빌드가 보낼 이유는 없다. 백엔드가 내 정보 조회까지
/// 토큰 기반으로 옮기면 이 장치를 걷어낸다.
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
  /// 서버가 인증 실패 응답에만 실어 주는 `errorCode` 를 본다. 자바 클래스 이름
  /// (`exception`)이 아니라 이걸 보는 이유는 저쪽이 리팩터링으로 조용히 바뀌기
  /// 때문이다. 이 판단이 어긋나면 무한 재발급이 된다.
  ///
  /// 백엔드 `AuthErrorCode` 의 이름과 같아야 한다. 기능 폴더의 상수를 쓰지 않고
  /// 여기 두는 것은 공통 모듈이 인증 폴더에 기대지 않게 하기 위해서다.
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
