import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../models/access_token_claims.dart';
import '../models/auth_tokens.dart';
import '../state/auth_api_scope.dart';
import '../state/auth_session.dart';
import '../state/auth_session_scope.dart';
import '../widgets/auth_page.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/obscure_toggle.dart';

/// 운영자 로그인 화면. 제목 → 아이디 → 비밀번호 → 하단 '로그인'.
///
/// 팬 앱 로그인 화면을 가져와 회원가입 링크를 뺐고, **관리자 계정만 통과**시키는
/// 판정을 더했다. 서버 로그인 API 는 역할을 보지 않고 누구든 로그인시켜 주므로,
/// 받은 토큰의 `roles` 클레임을 읽어 관리자가 아니면 세션에 담지 않는다.
///
/// 입력 형식은 검사하지 않고 두 칸이 채워졌는지만 본다. 맞는지 판정은 서버
/// 몫이기 때문이다.
///
/// 성공하면 받은 토큰을 [AuthSession] 에 담기만 한다(기기에도 저장됨). 화면
/// 이동은 하지 않는다 — 앱(App)이 세션을 구독하고 있어 로그인 상태가 되면
/// 이 화면을 스캔 화면으로 바꿔 그린다. 아이디·비밀번호가 틀리거나 관리자가
/// 아니면 칸 아래 문구, 정지·탈퇴 계정이나 네트워크 실패는 스낵바로 알린다.
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
      _fail(AuthStrings.loginFailed);
      return;
    }

    if (!AccessTokenClaims.parse(tokens.accessToken).isAdmin) {
      // 아이디·비밀번호는 맞았으니 서버에는 이 기기의 세션이 방금 생겼다. 쓰지
      // 않을 세션이라 끊어 둔다. 실패해도(네트워크) 로그인은 어차피 안 시키므로
      // 기다리지도, 알리지도 않는다.
      _revokeQuietly(tokens.refreshToken);
      _fail(AuthStrings.notAdmin);
      return;
    }

    // 토큰을 세션에 담으면 앱 전체가 로그인 상태가 되고 기기에도 저장된다.
    // 저장까지 끝난 뒤에야, 떠난 직후 앱을 죽여도 로그인 상태가 남는다.
    await _session.signIn(tokens);
    // 성공했을 때만 OS 에 "이 아이디·비밀번호를 저장할래?" 를 묻게 한다.
    // 틀린 비밀번호를 저장하라고 묻는 일이 없도록, 화면이 닫힐 때 무조건
    // 묻는 자동완성 그룹의 기본 동작은 아래 build 에서 꺼 두었다.
    TextInput.finishAutofillContext();
    // 앱에서는 세션이 바뀌는 순간 이 화면이 스캔 화면으로 교체돼 여기 오지
    // 않는다. 화면이 남아 있는 자리(단독 테스트)에서 스피너가 계속 돌지 않게 푼다.
    if (mounted) setState(() => _busy = false);
  }

  void _fail(String message) => setState(() {
    _busy = false;
    _errorText = message;
  });

  Future<void> _revokeQuietly(String refreshToken) async {
    try {
      await _api.logout(refreshToken);
    } on ApiException {
      // 못 알려도 그만. 서버 세션은 만료로 스스로 정리된다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AuthStrings.loginTitle, style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            AuthStrings.loginSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
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
              hint: AuthStrings.usernameHint,
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
              hint: AuthStrings.passwordHint,
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
          ],
        ),
      ),
    );
  }
}
