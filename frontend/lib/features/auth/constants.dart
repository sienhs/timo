/// 인증(회원가입·로그인) 도메인의 문구·크기 상수.
///
/// 글자수 한계 같은 숫자와 그 숫자를 설명하는 문구를 같은 곳에 두어
/// 한쪽만 바뀌는 일을 막는다(결제 도메인의 PaymentConstants 와 같은 방식).
class AuthMetrics {
  AuthMetrics._();

  /// 회원가입 단계 수. 화면 오른쪽 위 'n/4' 의 분모.
  static const totalSteps = 4;

  static const pagePadding = 20.0;
  static const headerLogoHeight = 24.0;
  static const completeLogoHeight = 32.0;

  /// 가입 완료 화면 가운데 마스코트 크기. 시안에서 화면 폭의 절반쯤을 차지한다.
  static const completeIllustrationSize = 160.0;

  /// 입력칸 높이. 옆에 붙는 '중복 확인' 버튼도 이 높이에 맞춘다.
  static const fieldHeight = 48.0;

  /// 010 + 8자리.
  static const phoneDigits = 11;
  static const codeLength = 6;

  /// 인증번호 유효 시간. 실제 값은 서버가 발송 응답으로 주고 화면은 그걸 쓴다.
  /// 이 상수는 서버 값 없이 화면이 열렸을 때(화면 단위 테스트, 딥링크)와 목의
  /// 응답에 쓰는 기본값이며 백엔드 SmsVerificationService 의 CODE_TTL 과 같다.
  static const codeValidity = Duration(minutes: 3);

  /// 인증 문자를 보낸 뒤 다시 요청할 수 있을 때까지 화면에서 기다리는 시간.
  /// 백엔드의 SEND_COOLDOWN 도 같은 값이어야 한다.
  static const resendCooldown = Duration(minutes: 1);

  /// DB `member.name` 컬럼 길이.
  static const nameMinLength = 2;
  static const nameMaxLength = 50;

  /// DB `login_info.username` 은 50자까지지만 UX 상 20자로 막는다.
  static const usernameMinLength = 4;
  static const usernameMaxLength = 20;

  /// 시안 문구 '닉네임 입력 (20글자까지)'. DB `member.nickname` 은 30자.
  static const nicknameMinLength = 2;
  static const nicknameMaxLength = 20;

  static const passwordMinLength = 8;
  static const passwordMaxLength = 20;

  /// 목 API 응답 지연. 실제 서버처럼 잠깐 기다려야 로딩 상태를 눈으로 볼 수 있다.
  static const mockLatency = Duration(milliseconds: 400);
}

/// 서버가 실패 응답(ProblemDetail)의 `exception` 에 싣는 오류 이름.
///
/// 백엔드 `domain/auth/exception` 패키지의 클래스 이름과 같아야 한다. 같은
/// 상태 코드(400·409) 안에서 원인을 가를 때 문구 대신 이 이름으로 비교한다.
/// 문구는 다듬느라 바뀌어도 클래스 이름은 잘 안 바뀌기 때문이다.
class AuthServerErrors {
  AuthServerErrors._();

  /// 인증번호가 틀림(400). 만료·횟수 초과와는 다르게 안내한다.
  static const smsCodeMismatch = 'SmsCodeMismatchException';

  /// 인증번호가 만료됐거나 없음(400). 화면의 남은 시간이 아직 남았어도 서버가
  /// 이걸 주면 만료로 본다.
  static const smsCodeNotFound = 'SmsCodeNotFoundException';

  static const smsSendLimitExceeded = 'SmsSendLimitExceededException';
  static const smsAttemptExceeded = 'SmsAttemptExceededException';
  static const smsSendFailed = 'SmsSendFailedException';

  /// 가입 시 인증 티켓이 만료됐거나 전화번호와 맞지 않음(400).
  static const verificationTicketInvalid = 'VerificationTicketInvalidException';

  /// 가입 시 닉네임 중복(409). 중복 확인과 가입 사이에 남이 채간 경우.
  static const nicknameDuplicated = 'NicknameDuplicatedException';

  /// 로그인 실패(400). 아이디 없음과 비밀번호 틀림을 서버가 하나로 묶어 준다.
  static const loginFailed = 'LoginFailedException';
}

class AuthStrings {
  AuthStrings._();

  // 공통
  static const next = '다음';
  static const duplicateCheck = '중복 확인';
  static String stepCounter(int step) => '$step / ${AuthMetrics.totalSteps}';

  // 1/4 기본 정보와 휴대폰 인증
  static const phoneTitle = '가입 정보를 입력해주세요';
  static const phoneSubtitle = '이름과 휴대폰 번호를 확인할게요';
  static const nameLabel = '이름';
  static const nameHint = '이름';
  static const nameRule = '한글 또는 영문으로 입력해주세요';
  static const phoneLabel = '휴대폰 번호';
  static const phoneHint = '010-0000-0000';
  static const requestCode = '인증번호 받기';
  static const codeSent = '인증번호를 보냈어요';

  // 첫 화면에서 이어지는 인증번호 입력
  static const codeLabel = '인증번호';
  static const codeHint = '인증번호 6자리';
  static const verify = '인증하기';
  static const codeMismatch = '인증번호를 다시 확인해주세요';
  static const codeExpired = '입력 시간이 지났어요. 인증번호를 다시 받아주세요';
  static const resendCode = '인증번호 다시 받기';
  static const codeResent = '인증번호를 다시 보냈어요';
  static const verificationComplete = '휴대폰 인증을 완료했어요';
  static const sendLimitExceeded = '인증번호 요청 횟수를 초과했어요.\n잠시 후 다시 시도해주세요';
  static const sendFailed = '인증번호를 보내지 못했어요.\n잠시 후 다시 시도해주세요';
  static const attemptExceeded = '인증 시도 횟수를 초과했어요.\n인증번호를 다시 받아주세요';

  /// 입력칸 안 남은 시간 표시를 스크린리더가 읽는 문구. 눈으로는 '02:59' 만 본다.
  static String remainingTime(String clock) => '남은 시간 $clock';

  // 2/4 아이디
  static const usernameTitle = '사용할 아이디를 정해주세요';
  static const usernameSubtitle = '로그인할 때 사용할 아이디예요';
  static const usernameLabel = '아이디';
  static const usernameHint = '아이디';
  static const usernameRule =
      '영문 소문자로 시작 · '
      '${AuthMetrics.usernameMinLength}~${AuthMetrics.usernameMaxLength}자';
  static const usernameAvailable = '사용할 수 있는 아이디예요';
  static const usernameTaken = '이미 사용 중이에요';

  // 아이디 확정 팝업. 2/4 에서 '다음' 을 누르면 뜬다.
  static const confirmTitle = '이 아이디를 사용할까요?';
  static const confirmBody = '가입한 뒤에는 아이디를 바꿀 수 없어요';
  static const confirmAgree = '이 아이디 사용하기';
  static const confirmEdit = '수정하기';

  // 3/4 비밀번호
  static const passwordTitle = '비밀번호를 설정해주세요';
  static const passwordSubtitle =
      '영문·숫자·특수문자를 포함해 ${AuthMetrics.passwordMinLength}~${AuthMetrics.passwordMaxLength}자로 입력해주세요';
  static const passwordLabel = '비밀번호';
  static const passwordHint = '비밀번호 입력';
  static const passwordConfirmLabel = '비밀번호 확인';
  static const passwordConfirmHint = '비밀번호 한 번 더 입력';
  static const passwordMismatch = '입력한 비밀번호가 서로 달라요';
  static const showPassword = '비밀번호 보기';
  static const hidePassword = '비밀번호 숨기기';

  // 4/4 닉네임
  static const nicknameTitle = '사용할 닉네임을 정해주세요';
  static const nicknameSubtitle = '다른 사람에게 보이는 이름이에요';
  static const nicknameLabel = '닉네임';
  static const nicknameHint = '닉네임 입력';
  static const nicknameRule =
      '한글·영문·숫자 · '
      '${AuthMetrics.nicknameMinLength}~${AuthMetrics.nicknameMaxLength}자';
  static const nicknameAvailable = '사용할 수 있는 닉네임이에요';
  static const nicknameTaken = '이미 사용 중이에요';
  static const startSignup = '가입하기';

  // 가입 완료
  static const completeTitle = '가입이 완료됐어요';
  static const completeSubtitle = '이제 티켓을 예매할 수 있어요';
  static const goToTickets = '티켓 보러 가기';

  // 로그인. 라벨은 회원가입의 usernameLabel·passwordLabel 을 그대로 쓴다.
  static const login = '로그인';

  /// 마이페이지 임시 버튼. 로그인 상태면 이 글자로 바뀐다.
  static const logout = '로그아웃';

  /// 시안의 힌트는 라벨과 같은 글자다('아이디 입력' 이 아니라 '아이디').
  static const loginUsernameHint = '아이디';
  static const loginPasswordHint = '비밀번호';

  /// 아이디가 없는 건지 비밀번호가 틀린 건지 구분해 주지 않는다. 구분해
  /// 주면 어떤 아이디가 가입돼 있는지를 밖에서 알아낼 수 있기 때문이다.
  static const loginFailed = '아이디 또는 비밀번호가 올바르지 않아요';

  /// 로그인 화면의 회원가입 링크.
  static const signup = '회원가입';
}
