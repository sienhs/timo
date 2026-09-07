import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../data/mock_auth_api.dart';
import '../models/signup_draft.dart';
import '../utils/phone_number_input_formatter.dart';
import '../utils/signup_validators.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_step_page.dart';

/// 1/5 본인인증 — 전화번호 입력. 회원가입 흐름의 첫 화면이다.
///
/// 인증번호를 보낸 뒤 [SignupCodeScreen] 으로 넘어가며, 전화번호는 하이픈을
/// 뺀 숫자만 초안에 담는다.
class SignupPhoneScreen extends StatefulWidget {
  const SignupPhoneScreen({
    super.key,
    this.draft = const SignupDraft(),
    this.api = const MockAuthApi(),
  });

  final SignupDraft draft;
  final AuthApi api;

  @override
  State<SignupPhoneScreen> createState() => _SignupPhoneScreenState();
}

class _SignupPhoneScreenState extends State<SignupPhoneScreen> {
  final _controller = TextEditingController();
  var _busy = false;

  String get _digits => SignupValidators.digitsOnly(_controller.text);

  bool get _canSubmit => !_busy && SignupValidators.isValidPhone(_digits);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phoneNumber = _digits;
    setState(() => _busy = true);
    await widget.api.requestVerificationCode(phoneNumber);
    if (!mounted) return;
    // 인증번호 화면에서 뒤로 돌아왔을 때 버튼이 살아 있어야 하므로 넘어가기
    // 전에 푼다.
    setState(() => _busy = false);
    Navigator.pushNamed(
      context,
      AppRoutes.signupCode,
      arguments: widget.draft.copyWith(phoneNumber: phoneNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 1,
      title: AuthStrings.verifyTitle,
      subtitle: AuthStrings.verifySubtitle,
      buttonLabel: AuthStrings.requestCode,
      isBusy: _busy,
      onPressed: _canSubmit ? _requestCode : null,
      child: LabeledTextField(
        label: AuthStrings.phoneLabel,
        hint: AuthStrings.phoneHint,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: const [PhoneNumberInputFormatter()],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (_canSubmit) _requestCode();
        },
      ),
    );
  }
}
