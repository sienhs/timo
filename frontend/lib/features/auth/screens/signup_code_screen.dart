import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../data/mock_auth_api.dart';
import '../models/signup_draft.dart';
import '../utils/signup_validators.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_step_page.dart';

/// 1/5 본인인증 — 인증번호 입력. 전화번호 화면과 같은 제목·단계를 쓴다.
///
/// 번호가 틀리면 칸 아래 오류 문구를 띄우고, 다시 타이핑하면 지운다.
class SignupCodeScreen extends StatefulWidget {
  const SignupCodeScreen({
    super.key,
    required this.draft,
    this.api = const MockAuthApi(),
  });

  final SignupDraft draft;
  final AuthApi api;

  @override
  State<SignupCodeScreen> createState() => _SignupCodeScreenState();
}

class _SignupCodeScreenState extends State<SignupCodeScreen> {
  final _controller = TextEditingController();
  var _busy = false;
  String? _errorText;

  bool get _canSubmit =>
      !_busy && SignupValidators.isValidCode(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _controller.text;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final verified = await widget.api.verifyCode(
      phoneNumber: widget.draft.phoneNumber,
      code: code,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!verified) _errorText = AuthStrings.codeMismatch;
    });
    if (!verified) return;
    Navigator.pushNamed(context, AppRoutes.signupName, arguments: widget.draft);
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 1,
      title: AuthStrings.verifyTitle,
      subtitle: AuthStrings.verifySubtitle,
      buttonLabel: AuthStrings.verify,
      isBusy: _busy,
      onPressed: _canSubmit ? _verify : null,
      child: LabeledTextField(
        label: AuthStrings.codeLabel,
        hint: AuthStrings.codeHint,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(AuthMetrics.codeLength),
        ],
        errorText: _errorText,
        onChanged: (_) => setState(() => _errorText = null),
        onSubmitted: (_) {
          if (_canSubmit) _verify();
        },
      ),
    );
  }
}
