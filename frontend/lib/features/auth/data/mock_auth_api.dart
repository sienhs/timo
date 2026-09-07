import '../constants.dart';
import '../models/signup_draft.dart';
import 'auth_api.dart';

/// 서버가 없는 동안 쓰는 가짜 [AuthApi].
///
/// 오류 화면도 눈으로 보고 테스트할 수 있도록 실패하는 값을 고정해 둔다.
/// 그 외 입력은 모두 성공한다.
/// - 인증번호 [invalidCode] 는 틀린 번호
/// - 아이디 [takenUsernames], 닉네임 [takenNicknames] 는 이미 사용 중
///
/// 응답마다 [latency] 만큼 기다려 실제 서버처럼 로딩 상태가 보이게 한다.
/// 테스트에서는 `Duration.zero` 를 넣어 바로 응답받는다.
class MockAuthApi implements AuthApi {
  const MockAuthApi({this.latency = AuthMetrics.mockLatency});

  final Duration latency;

  static const invalidCode = '000000';
  static const takenUsernames = {'timo', 'admin'};
  static const takenNicknames = {'티모'};

  Future<void> _respond() => Future<void>.delayed(latency);

  @override
  Future<void> requestVerificationCode(String phoneNumber) => _respond();

  @override
  Future<bool> verifyCode({
    required String phoneNumber,
    required String code,
  }) async {
    await _respond();
    return code != invalidCode;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await _respond();
    return !takenUsernames.contains(username);
  }

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    await _respond();
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<void> signUp(SignupDraft draft) => _respond();
}
