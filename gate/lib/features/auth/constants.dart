/// 인증(운영자 로그인) 도메인의 문구·크기 상수.
///
/// 팬 앱 `features/auth/constants.dart` 에서 게이트 앱에 필요한 것만 가져왔다.
/// 회원가입은 없다 — 게이트는 관리자 계정으로만 로그인한다.
class AuthMetrics {
  AuthMetrics._();

  static const pagePadding = 20.0;

  /// 헤더(제목·설명)와 입력칸 사이 간격.
  static const headerGap = 32.0;

  /// 목 API 응답 지연. 실제 서버처럼 잠깐 기다려야 로딩 상태를 눈으로 볼 수 있다.
  static const mockLatency = Duration(milliseconds: 400);
}

/// 서버가 인증 실패 응답의 `errorCode` 에 싣는 이유.
///
/// 백엔드 `AuthErrorCode` 열거형의 이름과 같아야 한다. [AuthServerErrors] 와
/// 역할이 겹쳐 보이지만, 저쪽은 자바 클래스 이름이라 백엔드가 클래스를 옮기면
/// 조용히 어긋난다. **인증 판단은 이걸로 한다.**
class AuthErrorCodes {
  AuthErrorCodes._();

  /// 액세스 토큰이 수명을 다했다(401). 재발급하면 풀린다.
  static const tokenExpired = 'TOKEN_EXPIRED';

  /// 토큰이 위조됐거나 폐기됐다(401). **재발급해도 소용없다.**
  static const tokenInvalid = 'TOKEN_INVALID';

  /// 폐기된 리프레시 토큰이 다시 쓰였다(401). 탈취로 보고 세션을 끊은 상태다.
  static const refreshReused = 'REFRESH_REUSED';
}

/// 서버가 실패 응답(ProblemDetail)의 `exception` 에 싣는 오류 이름.
///
/// 백엔드 `domain/auth/exception` 패키지의 클래스 이름과 같아야 한다.
class AuthServerErrors {
  AuthServerErrors._();

  /// 로그인 실패(400). 아이디 없음과 비밀번호 틀림을 서버가 하나로 묶어 준다.
  static const loginFailed = 'LoginFailedException';
}

/// 액세스 토큰(JWT)의 `roles` 클레임 값. 백엔드 `Role` 열거형의 이름과 같다.
class AuthRoles {
  AuthRoles._();

  /// 게이트 앱에 로그인할 수 있는 유일한 역할.
  static const admin = 'ADMIN';
}

class AuthStrings {
  AuthStrings._();

  // 로그인 화면
  static const loginTitle = '운영자 로그인';
  static const loginSubtitle = '관리자 계정으로 로그인해주세요';
  static const usernameLabel = '아이디';
  static const usernameHint = '아이디';
  static const passwordLabel = '비밀번호';
  static const passwordHint = '비밀번호';
  static const login = '로그인';
  static const showPassword = '비밀번호 보기';
  static const hidePassword = '비밀번호 숨기기';

  /// 아이디가 없는 건지 비밀번호가 틀린 건지 구분해 주지 않는다. 구분해
  /// 주면 어떤 아이디가 가입돼 있는지를 밖에서 알아낼 수 있기 때문이다.
  static const loginFailed = '아이디 또는 비밀번호가 올바르지 않아요';

  /// 아이디·비밀번호는 맞지만 관리자 계정이 아닐 때. 팬 계정으로는 검표할 수 없다.
  static const notAdmin = '관리자 계정만 로그인할 수 있어요';

  // 로그아웃. 스캔 화면 오른쪽 위 버튼과 확인 팝업.
  static const logout = '로그아웃';
  static const logoutConfirmTitle = '로그아웃할까요?';
  static const logoutConfirmBody = '다시 검표하려면 관리자 계정으로 다시 로그인해야 해요';
  static const cancel = '취소';
}
