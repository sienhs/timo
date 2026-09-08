import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../data/mock_auth_api.dart';
import '../widgets/auth_page.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/obscure_toggle.dart';
import '../widgets/timo_logo.dart';

/// 로그인 화면. 로고 → 아이디 → 비밀번호 → '회원가입' 링크 → 하단 '로그인'.
///
/// 입력 형식은 검사하지 않고 두 칸이 채워졌는지만 본다. 가입 규칙이 나중에
/// 바뀌어도 기존 계정이 로그인 못 하는 일이 없어야 하고, 맞는지 판정은 서버
/// 몫이기 때문이다.
///
/// 성공하면 이전 화면으로 돌아가며 결과로 true 를 넘긴다. 로그인 상태를
/// 저장하는 일은 다음 작업에서 이 값을 받아 처리한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.api = const MockAuthApi()});

  final AuthApi api;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  var _obscurePassword = true;
  var _busy = false;
  String? _errorText;

  /// 앞뒤 공백은 오타로 보고 잘라낸다. 비밀번호는 공백도 글자라 그대로 둔다.
  String get _username => _usernameController.text.trim();

  String get _password => _passwordController.text;

  bool get _canSubmit => !_busy && _username.isNotEmpty && _password.isNotEmpty;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// 어느 칸이든 고치면 이전 실패 문구는 무효다. 버튼이 켜질지도 글자에
  /// 달려 있어 항상 다시 그린다.
  void _onChanged(String _) => setState(() => _errorText = null);

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final ok = await widget.api.login(username: _username, password: _password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _errorText = AuthStrings.loginFailed;
    });
    if (!ok) return;
    // 성공했을 때만 OS 에 "이 아이디·비밀번호를 저장할래?" 를 묻게 한다.
    // 틀린 비밀번호를 저장하라고 묻는 일이 없도록, 화면이 닫힐 때 무조건
    // 묻는 자동완성 그룹의 기본 동작은 아래 build 에서 꺼 두었다.
    TextInput.finishAutofillContext();
    Navigator.pop(context, true);
  }

  void _goSignup() => Navigator.pushNamed(context, AppRoutes.signupPhone);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthPage(
      // 공통 틀 본문은 가로로 늘리는 배치라, 그냥 두면 로고가 가운데로 간다.
      header: const Align(alignment: Alignment.centerLeft, child: TimoLogo()),
      buttonLabel: AuthStrings.login,
      onPressed: _canSubmit ? _login : null,
      isBusy: _busy,
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabeledTextField(
              label: AuthStrings.usernameLabel,
              hint: AuthStrings.loginUsernameHint,
              controller: _usernameController,
              autofocus: true,
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: _onChanged,
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 24),
            LabeledTextField(
              label: AuthStrings.passwordLabel,
              hint: AuthStrings.loginPasswordHint,
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: _obscurePassword,
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: _errorText,
              onChanged: _onChanged,
              onSubmitted: (_) {
                if (_canSubmit) _login();
              },
              suffixIcon: ObscureToggle(
                obscured: _obscurePassword,
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goSignup,
                style: TextButton.styleFrom(
                  // 작은 글자라 브랜드색 그대로면 흰 배경 대비가 기준(4.5:1)
                  // 에 못 미친다. 눌린 색으로 정의된 진한 초록을 쓴다.
                  foregroundColor: AppColors.primaryPressed,
                  textStyle: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  // 글자가 입력칸 오른쪽 끝에 맞도록 안쪽 여백을 줄이고,
                  // 높이는 권장 터치 크기(44)를 지킨다.
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 44),
                ),
                child: const Text(AuthStrings.signup),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
