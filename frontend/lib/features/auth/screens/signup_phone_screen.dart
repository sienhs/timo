import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../models/signup_draft.dart';
import '../state/auth_api_scope.dart';
import '../utils/phone_number_input_formatter.dart';
import '../utils/signup_validators.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_step_page.dart';
import 'signup_code_screen.dart';

/// 1/5 본인인증 — 전화번호 입력. 회원가입 흐름의 첫 화면이다.
///
/// 인증번호를 보낸 뒤 [SignupCodeScreen] 으로 넘어가며, 전화번호는 하이픈을
/// 뺀 숫자만 초안에 담는다. 발송 실패(횟수 초과, 네트워크)는 스낵바로 알리고
/// 버튼을 다시 켠다.
class SignupPhoneScreen extends StatefulWidget {
  const SignupPhoneScreen({
    super.key,
    this.draft = const SignupDraft(),
    this.api,
  });

  final SignupDraft draft;

  /// 직접 넘기면 그걸 쓰고(테스트), 안 넘기면 [AuthApiScope] 에서 받는다(앱).
  final AuthApi? api;

  @override
  State<SignupPhoneScreen> createState() => _SignupPhoneScreenState();
}

class _SignupPhoneScreenState extends State<SignupPhoneScreen> {
  final _controller = TextEditingController();
  var _busy = false;

  AuthApi get _api => widget.api ?? AuthApiScope.of(context);

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

    final Duration validFor;
    try {
      validFor = await _api.requestVerificationCode(phoneNumber);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, e.message);
      return;
    }

    if (!mounted) return;
    // 인증번호 화면에서 뒤로 돌아왔을 때 버튼이 살아 있어야 하므로 넘어가기
    // 전에 푼다.
    setState(() => _busy = false);
    Navigator.pushNamed(
      context,
      AppRoutes.signupCode,
      // 서버가 준 유효 시간을 함께 넘겨 인증번호 화면이 남은 시간을 센다.
      arguments: SignupCodeArguments(
        draft: widget.draft.copyWith(phoneNumber: phoneNumber),
        validFor: validFor,
      ),
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
