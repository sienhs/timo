import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/signup_draft.dart';
import '../utils/signup_validators.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_step_page.dart';

/// 2/5 이름 입력. 서버 요청이 없는 유일한 단계라 API 를 받지 않는다.
///
/// 한글은 조합 중인 글자가 잠깐 들어오므로 입력 필터를 걸지 않고, 글자수만
/// 제한한 뒤 다 친 값을 검사한다.
class SignupNameScreen extends StatefulWidget {
  const SignupNameScreen({super.key, required this.draft});

  final SignupDraft draft;

  @override
  State<SignupNameScreen> createState() => _SignupNameScreenState();
}

class _SignupNameScreenState extends State<SignupNameScreen> {
  final _controller = TextEditingController();

  bool get _canSubmit => SignupValidators.isValidName(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goNext() {
    Navigator.pushNamed(
      context,
      AppRoutes.signupUsername,
      arguments: widget.draft.copyWith(name: _controller.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 2,
      title: AuthStrings.nameTitle,
      subtitle: AuthStrings.nameSubtitle,
      buttonLabel: AuthStrings.next,
      onPressed: _canSubmit ? _goNext : null,
      child: LabeledTextField(
        label: AuthStrings.nameLabel,
        hint: AuthStrings.nameHint,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          LengthLimitingTextInputFormatter(AuthMetrics.nameMaxLength),
        ],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          if (_canSubmit) _goNext();
        },
      ),
    );
  }
}
