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
import '../utils/signup_validators.dart';
import '../widgets/duplicate_check_button.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/obscure_toggle.dart';
import '../widgets/signup_step_page.dart';

/// 2/3 로그인 정보. 아이디와 비밀번호를 한 화면에서 받는다.
///
/// 아이디와 비밀번호는 둘 다 '로그인할 때 쓰는 것' 이라 따로 물을 이유가 없었다.
/// 칸 하나짜리 화면 둘을 하나로 합쳐 가입 단계를 4 에서 3 으로 줄였다.
///
/// 아이디 중복 확인은 **칸에서 포커스가 빠질 때 저절로** 한다. 사용자가 비밀번호
/// 칸으로 내려가는 사이에 끝나 있어서 '중복 확인' 을 누를 일이 거의 없다. 버튼을
/// 남겨 둔 건 네트워크가 끊겼을 때 다시 시도할 수단이 필요해서다.
///
/// '다음으로' 는 아이디 중복 확인을 통과하고, 비밀번호가 규칙에 맞고, 확인 칸이
/// 같을 때만 켜진다.
class SignupAccountScreen extends StatefulWidget {
  const SignupAccountScreen({super.key, required this.draft, this.api});

  final SignupDraft draft;

  /// 직접 넘기면 그걸 쓰고(테스트), 안 넘기면 [AuthApiScope] 에서 받는다(앱).
  final AuthApi? api;

  @override
  State<SignupAccountScreen> createState() => _SignupAccountScreenState();
}

class _SignupAccountScreenState extends State<SignupAccountScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  var _status = AvailabilityStatus.unchecked;
  var _obscurePassword = true;
  var _obscureConfirm = true;

  AuthApi get _api => widget.api ?? AuthApiScope.of(context);

  String get _username => _usernameController.text;

  String get _password => _passwordController.text;

  String get _confirm => _confirmController.text;

  bool get _usernameFormatValid => SignupValidators.isValidUsername(_username);

  bool get _canCheck =>
      _usernameFormatValid && _status != AvailabilityStatus.checking;

  bool get _passwordValid => SignupValidators.isValidPassword(_password);

  bool get _mismatch => _confirm.isNotEmpty && _confirm != _password;

  bool get _canSubmit =>
      _status == AvailabilityStatus.available &&
      _passwordValid &&
      _confirm == _password;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(_checkOnFocusLost);
  }

  @override
  void dispose() {
    _usernameFocus.removeListener(_checkOnFocusLost);
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  /// 아이디 칸을 벗어나는 순간 중복 확인을 대신 눌러 준다.
  ///
  /// [AvailabilityStatus.unchecked] 일 때만 부르는 것이 재요청을 막는 장치다.
  /// 결과가 한 번 나오면 상태가 available·taken 으로 바뀌므로, 글자를 고치지
  /// 않고 칸을 드나들어도 같은 값으로 다시 묻지 않는다. 요청이 실패하면 상태가
  /// unchecked 로 돌아가는데, 그때는 다시 들렀다 나갈 때 재시도되는 게 맞다.
  void _checkOnFocusLost() {
    if (_usernameFocus.hasFocus) return;
    if (!_canCheck || _status != AvailabilityStatus.unchecked) return;
    _check();
  }

  /// 글자가 바뀌면 이전 확인 결과는 무효다.
  void _onUsernameChanged(String _) =>
      setState(() => _status = AvailabilityStatus.unchecked);

  Future<void> _check() async {
    final candidate = _username;
    setState(() => _status = AvailabilityStatus.checking);

    final bool available;
    try {
      available = await _api.isUsernameAvailable(candidate);
    } on ApiException catch (e) {
      // 확인이 안 된 것이지 결과가 난 게 아니므로 '확인 안 함' 으로 돌려
      // 다시 누를 수 있게 하고, 이유는 스낵바로 알린다.
      if (!mounted || _usernameController.text != candidate) return;
      setState(() => _status = AvailabilityStatus.unchecked);
      showErrorSnackBar(context, e.message);
      return;
    }

    // 응답이 오기 전에 글자를 고쳤으면 옛 값에 대한 결과이므로 버린다.
    if (!mounted || _usernameController.text != candidate) return;
    setState(() {
      _status = available
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    });
  }

  void _goNext() {
    Navigator.pushNamed(
      context,
      AppRoutes.signupNickname,
      arguments: widget.draft.copyWith(
        username: _username,
        password: _password,
      ),
    );
  }

  /// 아이디 칸 아래 문구. 중복 오류가 최우선, 그다음 사용 가능(파랑), 형식이
  /// 틀린 동안에만 규칙 안내.
  String? get _usernameError =>
      _status == AvailabilityStatus.taken ? AuthStrings.usernameTaken : null;

  String? get _usernameHelper {
    if (_status == AvailabilityStatus.available) {
      return AuthStrings.usernameAvailable;
    }
    if (_username.isNotEmpty && !_usernameFormatValid) {
      return AuthStrings.usernameRule;
    }
    return null;
  }

  Color? get _usernameHelperColor =>
      _status == AvailabilityStatus.available ? AppColors.primary : null;

  @override
  Widget build(BuildContext context) {
    final passwordLengthLimit = LengthLimitingTextInputFormatter(
      AuthMetrics.passwordMaxLength,
    );

    return SignupStepPage(
      step: 2,
      title: AuthStrings.accountTitle,
      subtitle: AuthStrings.accountSubtitle,
      buttonLabel: AuthStrings.next,
      onPressed: _canSubmit ? _goNext : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledTextField(
            label: AuthStrings.usernameLabel,
            hint: AuthStrings.usernameHint,
            controller: _usernameController,
            focusNode: _usernameFocus,
            autofocus: true,
            keyboardType: TextInputType.text,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            inputFormatters: [
              // 대문자로 쳐도 소문자로 받는다. 대문자를 그냥 버리면 'Timo' 가
              // 'imo' 로 보여 당황스럽다.
              TextInputFormatter.withFunction(
                (oldValue, newValue) =>
                    newValue.copyWith(text: newValue.text.toLowerCase()),
              ),
              FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
              LengthLimitingTextInputFormatter(AuthMetrics.usernameMaxLength),
            ],
            helperText: _usernameHelper,
            helperColor: _usernameHelperColor,
            errorText: _usernameError,
            onChanged: _onUsernameChanged,
            // 포커스가 비밀번호로 넘어가면서 중복 확인이 저절로 걸린다.
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            trailing: DuplicateCheckButton(
              onPressed: _canCheck ? _check : null,
              isChecking: _status == AvailabilityStatus.checking,
            ),
          ),
          const SizedBox(height: 24),
          LabeledTextField(
            label: AuthStrings.passwordLabel,
            hint: AuthStrings.passwordHint,
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            inputFormatters: [passwordLengthLimit],
            helperText: _passwordValid ? null : AuthStrings.passwordRule,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _confirmFocus.requestFocus(),
            suffixIcon: ObscureToggle(
              obscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 24),
          LabeledTextField(
            label: AuthStrings.passwordConfirmLabel,
            hint: AuthStrings.passwordConfirmHint,
            controller: _confirmController,
            focusNode: _confirmFocus,
            obscureText: _obscureConfirm,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            inputFormatters: [passwordLengthLimit],
            errorText: _mismatch ? AuthStrings.passwordMismatch : null,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (_canSubmit) _goNext();
            },
            suffixIcon: ObscureToggle(
              obscured: _obscureConfirm,
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ],
      ),
    );
  }
}
