import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../models/availability_status.dart';
import '../models/signup_draft.dart';
import '../state/auth_api_scope.dart';
import '../state/auth_session.dart';
import '../state/auth_session_scope.dart';
import '../utils/signup_validators.dart';
import '../widgets/duplicate_check_button.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_step_page.dart';

/// 3/3 닉네임 설정. 회원가입의 마지막 입력 화면. 중복 확인은 아이디 칸과 같이
/// 포커스가 빠지면 저절로 한다. 가입을 요청해 성공하면 입력 화면들을 스택에서
/// 전부 지우고 완료 화면으로 간다. 거절 안내는 [_handleSignUpFailure] 참고.
class SignupNicknameScreen extends StatefulWidget {
  const SignupNicknameScreen({
    super.key,
    required this.draft,
    this.api,
    this.session,
  });

  final SignupDraft draft;

  /// 직접 넘기면 그걸 쓰고(테스트), 안 넘기면 [AuthApiScope] 에서 받는다(앱).
  final AuthApi? api;

  /// 가입 성공 토큰을 담을 곳. 안 넘기면 [AuthSessionScope] 에서 받는다.
  final AuthSession? session;

  @override
  State<SignupNicknameScreen> createState() => _SignupNicknameScreenState();
}

class _SignupNicknameScreenState extends State<SignupNicknameScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  var _status = AvailabilityStatus.unchecked;
  var _busy = false;

  AuthApi get _api => widget.api ?? AuthApiScope.of(context);

  AuthSession get _session => widget.session ?? AuthSessionScope.read(context);

  String get _nickname => _controller.text.trim();

  bool get _formatValid => SignupValidators.isValidNickname(_nickname);

  bool get _canCheck => _formatValid && _status != AvailabilityStatus.checking;

  bool get _canSubmit => !_busy && _status == AvailabilityStatus.available;

  String? get _errorText =>
      _status == AvailabilityStatus.taken ? AuthStrings.nicknameTaken : null;

  String? get _helperText {
    if (_status == AvailabilityStatus.available) {
      return AuthStrings.nicknameAvailable;
    }
    if (_nickname.isNotEmpty && !_formatValid) return AuthStrings.nicknameRule;
    return null;
  }

  Color? get _helperColor =>
      _status == AvailabilityStatus.available ? AppColors.primary : null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_checkOnFocusLost);
  }

  @override
  void dispose() {
    _focus.removeListener(_checkOnFocusLost);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 칸을 벗어나는 순간 중복 확인을 대신 눌러 준다. 아이디 칸과 같은 규칙이다
  /// (SignupAccountScreen 참고). unchecked 일 때만 불러 같은 값을 다시 묻지 않는다.
  void _checkOnFocusLost() {
    if (_focus.hasFocus) return;
    if (!_canCheck || _status != AvailabilityStatus.unchecked) return;
    _check();
  }

  void _onChanged(String _) =>
      setState(() => _status = AvailabilityStatus.unchecked);

  Future<void> _check() async {
    final candidate = _nickname;
    setState(() => _status = AvailabilityStatus.checking);

    final bool available;
    try {
      available = await _api.isNicknameAvailable(candidate);
    } on ApiException catch (e) {
      // 확인이 안 된 것이지 결과가 난 게 아니므로 '확인 안 함' 으로 돌려
      // 다시 누를 수 있게 하고, 이유는 스낵바로 알린다.
      if (!mounted || _nickname != candidate) return;
      setState(() => _status = AvailabilityStatus.unchecked);
      showErrorSnackBar(context, e.message);
      return;
    }

    // 응답이 오기 전에 글자를 고쳤으면 옛 값에 대한 결과이므로 버린다.
    if (!mounted || _nickname != candidate) return;
    setState(() {
      _status = available
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    });
  }

  Future<void> _signUp() async {
    setState(() => _busy = true);
    try {
      // 가입 응답에도 로그인 토큰이 온다. 세션에 담아 가입 즉시 로그인 상태로
      // 만든다(기기에도 저장됨). 가입한 사람에게 다시 로그인하라고 할 이유가 없다.
      final tokens = await _api.signUp(
        widget.draft.copyWith(nickname: _nickname),
      );
      await _session.signIn(tokens);
    } on ApiException catch (e) {
      if (!mounted) return;
      _handleSignUpFailure(e);
      return;
    }
    if (!mounted) return;
    // 입력 화면으로 돌아올 일이 없으니 _busy 는 풀지 않는다. 스택을 [홈 탭, 지갑
    // 연출] 로 다시 세우면 연출이 완료 화면으로 바뀌어 홈 탭 위에 완료만 남는다.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
    Navigator.pushNamed(context, AppRoutes.signupWallet);
  }

  /// 가입 거절 원인별 안내. 닉네임 중복(409)은 칸 아래 문구로 알리고 다시
  /// 확인하게 한다 · 인증 만료(400)는 스낵바로 알린 뒤 전화번호 화면으로
  /// 되돌아간다 · 그 외(아이디·전화번호 중복, 네트워크)는 스낵바로 알리고
  /// 버튼을 풀어 다시 시도하게 한다.
  void _handleSignUpFailure(ApiException e) {
    final nicknameTaken =
        e.exceptionName == AuthServerErrors.nicknameDuplicated;
    setState(() {
      _busy = false;
      if (nicknameTaken) _status = AvailabilityStatus.taken;
    });
    if (nicknameTaken) return;

    showErrorSnackBar(context, e.message);
    if (e.exceptionName == AuthServerErrors.verificationTicketInvalid) {
      // 전화번호 화면이 스택에 없는 경우(화면 단독 실행)에는 첫 화면에서 멈춘다.
      Navigator.popUntil(
        context,
        (route) =>
            route.settings.name == AppRoutes.signupPhone || route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 3,
      title: AuthStrings.nicknameTitle,
      subtitle: AuthStrings.nicknameSubtitle,
      buttonLabel: AuthStrings.startSignup,
      isBusy: _busy,
      onPressed: _canSubmit ? _signUp : null,
      child: LabeledTextField(
        label: AuthStrings.nicknameLabel,
        hint: AuthStrings.nicknameHint,
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        // 한글은 조합 중 글자가 잠깐 들어오므로 글자 필터는 걸지 않는다.
        inputFormatters: [
          LengthLimitingTextInputFormatter(AuthMetrics.nicknameMaxLength),
        ],
        helperText: _helperText,
        helperColor: _helperColor,
        errorText: _errorText,
        onChanged: _onChanged,
        onSubmitted: (_) {
          if (_canCheck) _check();
        },
        trailing: DuplicateCheckButton(
          onPressed: _canCheck ? _check : null,
          isChecking: _status == AvailabilityStatus.checking,
        ),
      ),
    );
  }
}
