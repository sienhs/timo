import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../data/auth_api.dart';
import '../data/mock_auth_api.dart';
import '../models/availability_status.dart';
import '../models/signup_draft.dart';
import '../utils/signup_validators.dart';
import '../widgets/duplicate_check_button.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_confirm_dialog.dart';
import '../widgets/signup_step_page.dart';

/// 3/5 아이디 설정.
///
/// '중복 확인' 을 통과해야 '다음으로' 가 켜지고, 글자를 고치면 다시 확인해야
/// 한다. '다음으로' 를 누르면 아이디 확정 팝업이 뜨고, 동의하면 비밀번호
/// 화면으로 간다. 가입 뒤에는 아이디를 바꿀 수 없기 때문이다.
class SignupUsernameScreen extends StatefulWidget {
  const SignupUsernameScreen({
    super.key,
    required this.draft,
    this.api = const MockAuthApi(),
  });

  final SignupDraft draft;
  final AuthApi api;

  @override
  State<SignupUsernameScreen> createState() => _SignupUsernameScreenState();
}

class _SignupUsernameScreenState extends State<SignupUsernameScreen> {
  final _controller = TextEditingController();
  var _status = AvailabilityStatus.unchecked;

  String get _username => _controller.text;

  bool get _formatValid => SignupValidators.isValidUsername(_username);

  bool get _canCheck => _formatValid && _status != AvailabilityStatus.checking;

  bool get _canSubmit => _status == AvailabilityStatus.available;

  /// 칸 아래 문구. 중복 오류가 최우선, 그다음 사용 가능(초록), 형식이 틀린
  /// 동안에만 규칙 안내.
  String? get _errorText =>
      _status == AvailabilityStatus.taken ? AuthStrings.usernameTaken : null;

  String? get _helperText {
    if (_status == AvailabilityStatus.available) {
      return AuthStrings.usernameAvailable;
    }
    if (_username.isNotEmpty && !_formatValid) return AuthStrings.usernameRule;
    return null;
  }

  Color? get _helperColor =>
      _status == AvailabilityStatus.available ? AppColors.primary : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 글자가 바뀌면 이전 확인 결과는 무효다.
  void _onChanged(String _) =>
      setState(() => _status = AvailabilityStatus.unchecked);

  Future<void> _check() async {
    final candidate = _username;
    setState(() => _status = AvailabilityStatus.checking);
    final available = await widget.api.isUsernameAvailable(candidate);
    // 응답이 오기 전에 글자를 고쳤으면 옛 값에 대한 결과이므로 버린다.
    if (!mounted || _controller.text != candidate) return;
    setState(() {
      _status = available
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    });
  }

  Future<void> _goNext() async {
    final agreed = await showSignupConfirmDialog(context);
    if (!agreed || !mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.signupPassword,
      arguments: widget.draft.copyWith(username: _username),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 3,
      title: AuthStrings.usernameTitle,
      subtitle: AuthStrings.usernameSubtitle,
      buttonLabel: AuthStrings.next,
      onPressed: _canSubmit ? _goNext : null,
      child: LabeledTextField(
        label: AuthStrings.usernameLabel,
        hint: AuthStrings.usernameHint,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.text,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
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
