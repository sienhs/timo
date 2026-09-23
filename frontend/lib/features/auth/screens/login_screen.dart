import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../models/auth_tokens.dart';
import '../state/auth_api_scope.dart';
import '../state/auth_session.dart';
import '../state/auth_session_scope.dart';
import '../widgets/auth_page.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/obscure_toggle.dart';
import '../../../core/widgets/timo_logo.dart';

/// 로그인 화면. 로고 → 아이디 → 비밀번호 → '회원가입' 링크 → 하단 '로그인'.
/// 입력 형식은 검사하지 않고 두 칸이 채워졌는지만 본다(판정은 서버 몫). 성공하면
/// 토큰을 [AuthSession] 에 담고 홈 탭으로 간다([_goHome]).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.api, this.session});

  /// 직접 넘기면 그걸 쓰고(테스트), 안 넘기면 [AuthApiScope] 에서 받는다(앱).
  final AuthApi? api;

  /// 마찬가지. 안 넘기면 [AuthSessionScope] 에서 받는다.
  final AuthSession? session;

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

  AuthApi get _api => widget.api ?? AuthApiScope.of(context);

  AuthSession get _session => widget.session ?? AuthSessionScope.read(context);

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

    final AuthTokens? tokens;
    try {
      tokens = await _api.login(username: _username, password: _password);
    } on ApiException catch (e) {
      // 정지·탈퇴 계정(403), 네트워크 끊김. 입력이 틀린 게 아니라 칸 아래가
      // 아닌 스낵바로 알리고 다시 시도할 수 있게 버튼을 푼다.
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, e.message);
      return;
    }

    if (!mounted) return;
    if (tokens == null) {
      setState(() {
        _busy = false;
        _errorText = AuthStrings.loginFailed;
      });
      return;
    }

    // 토큰을 세션에 담으면 앱 전체가 로그인 상태가 되고 기기에도 저장된다.
    // 저장까지 끝난 뒤 떠나야, 떠난 직후 앱을 죽여도 로그인 상태가 남는다.
    await _session.signIn(tokens);
    if (!mounted) return;
    // 성공했을 때만 OS 에 로그인 정보 저장을 묻게 한다. 화면이 닫힐 때 무조건
    // 묻는 자동완성 그룹의 기본 동작은 build 에서 꺼 두었다.
    TextInput.finishAutofillContext();
    _goHome();
  }

  /// 로그인을 마치면 어디서 들어왔든 홈 탭으로 간다. 여러 곳에서 열리는 화면이라
  /// 이전 화면으로 되돌리면 동작이 화면마다 달라, 홈을 새로 세우고 전부 걷어낸다.
  void _goHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
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
