import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/signup_draft.dart';
import '../utils/signup_validators.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/obscure_toggle.dart';
import '../widgets/signup_step_page.dart';

/// 3/4 비밀번호 설정. 비밀번호와 확인 두 칸.
///
/// 규칙(8~20자, 영문·숫자·특수문자)을 만족하고 두 칸이 같아야 '다음으로' 가
/// 켜진다. 확인 칸이 비어 있지 않은데 다르면 바로 오류 문구를 띄운다.
/// 서버 요청이 없는 단계라 API 를 받지 않는다.
class SignupPasswordScreen extends StatefulWidget {
  const SignupPasswordScreen({super.key, required this.draft});

  final SignupDraft draft;

  @override
  State<SignupPasswordScreen> createState() => _SignupPasswordScreenState();
}

class _SignupPasswordScreenState extends State<SignupPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _confirmFocus = FocusNode();
  var _obscurePassword = true;
  var _obscureConfirm = true;

  String get _password => _passwordController.text;

  String get _confirm => _confirmController.text;

  bool get _passwordValid => SignupValidators.isValidPassword(_password);

  bool get _mismatch => _confirm.isNotEmpty && _confirm != _password;

  bool get _canSubmit => _passwordValid && _confirm == _password;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _goNext() {
    Navigator.pushNamed(
      context,
      AppRoutes.signupNickname,
      arguments: widget.draft.copyWith(password: _password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lengthLimit = LengthLimitingTextInputFormatter(
      AuthMetrics.passwordMaxLength,
    );

    return SignupStepPage(
      step: 3,
      title: AuthStrings.passwordTitle,
      subtitle: AuthStrings.passwordSubtitle,
      buttonLabel: AuthStrings.next,
      onPressed: _canSubmit ? _goNext : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledTextField(
            label: AuthStrings.passwordLabel,
            hint: AuthStrings.passwordHint,
            controller: _passwordController,
            autofocus: true,
            obscureText: _obscurePassword,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            inputFormatters: [lengthLimit],
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
            inputFormatters: [lengthLimit],
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
