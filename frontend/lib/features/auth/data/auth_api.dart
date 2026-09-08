import '../models/signup_draft.dart';

/// 인증(회원가입·로그인) 화면이 서버에 요청하는 일 여섯 가지.
///
/// 화면은 이 인터페이스만 알고, 지금은 [MockAuthApi] 가 꽂혀 있다. 백엔드
/// API 가 나오면 같은 인터페이스를 구현한 클래스로 바꿔 끼우고 화면은 그대로
/// 둔다.
///
/// 반환 규칙:
/// - 정상 흐름에서 예상되는 결과(번호 불일치, 이미 쓰는 아이디)는 `bool` 로
///   돌려준다. 화면이 `if` 한 줄로 처리할 수 있다.
/// - 네트워크 오류·서버 오류처럼 예상 밖의 실패는 예외로 던진다. 실제 구현
///   에서는 ProblemDetail 의 `errorMessage` 를 담아 던지고 화면은 스낵바로
///   보여준다(api-response-convention). 목 구현에는 해당 없음.
abstract class AuthApi {
  /// [phoneNumber] 로 인증번호를 보낸다. 숫자만 ('01012345678').
  Future<void> requestVerificationCode(String phoneNumber);

  /// 받은 인증번호가 맞으면 true.
  Future<bool> verifyCode({required String phoneNumber, required String code});

  Future<bool> isUsernameAvailable(String username);

  Future<bool> isNicknameAvailable(String nickname);

  Future<void> signUp(SignupDraft draft);

  /// 아이디·비밀번호가 맞으면 true. 틀린 것은 예상되는 결과라 false 로
  /// 돌려주고 예외로 던지지 않는다.
  Future<bool> login({required String username, required String password});
}
