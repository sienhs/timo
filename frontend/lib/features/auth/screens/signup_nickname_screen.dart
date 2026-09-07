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
import '../widgets/signup_step_page.dart';

/// 5/5 닉네임 설정. 회원가입의 마지막 입력 화면.
///
/// 중복 확인 흐름은 아이디 화면과 같다. '인증하고 시작하기' 를 누르면 지금까지
/// 모은 초안으로 가입을 요청하고 완료 화면으로 간다. 이때 입력 화면들은
/// 스택에서 전부 지워서, 완료 화면에서 뒤로가기를 눌러도 입력 화면으로
/// 돌아가지 않고 홈으로 간다.
class SignupNicknameScreen extends StatefulWidget {
  const SignupNicknameScreen({
    super.key,
    required this.draft,
    this.api = const MockAuthApi(),
  });

  final SignupDraft draft;
  final AuthApi api;

  @override
  State<SignupNicknameScreen> createState() => _SignupNicknameScreenState();
}

class _SignupNicknameScreenState extends State<SignupNicknameScreen> {
  final _controller = TextEditingController();
  var _status = AvailabilityStatus.unchecked;
  var _busy = false;

  String get _nickname => _controller.text.trim();

  bool get _formatValid => SignupValidators.isValidNickname(_nickname);

  bool get _canCheck => _formatValid && _status != AvailabilityStatus.checking;

  bool get _canSubmit => !_busy && _status == AvailabilityStatus.available;

  String? get _errorText =>
      _status == AvailabilityStatus.taken ? AuthStrings.nicknameTaken : null;

  String? get _helperText {
    if (_status == AvailabilityStatus.available) {
      return AuthStrings.nicknameAvailable;
    }
    if (_nickname.isNotEmpty && !_formatValid) return AuthStrings.nicknameRule;
    return null;
  }

  Color? get _helperColor =>
      _status == AvailabilityStatus.available ? AppColors.primary : null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String _) =>
      setState(() => _status = AvailabilityStatus.unchecked);

  Future<void> _check() async {
    final candidate = _nickname;
    setState(() => _status = AvailabilityStatus.checking);
    final available = await widget.api.isNicknameAvailable(candidate);
    // 응답이 오기 전에 글자를 고쳤으면 옛 값에 대한 결과이므로 버린다.
    if (!mounted || _nickname != candidate) return;
    setState(() {
      _status = available
          ? AvailabilityStatus.available
          : AvailabilityStatus.taken;
    });
  }

  Future<void> _signUp() async {
    setState(() => _busy = true);
    await widget.api.signUp(widget.draft.copyWith(nickname: _nickname));
    if (!mounted) return;
    // 뒤로가기로 입력 화면에 돌아올 일이 없으니 _busy 는 풀지 않는다.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.signupComplete,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 5,
      title: AuthStrings.nicknameTitle,
      subtitle: AuthStrings.nicknameSubtitle,
      buttonLabel: AuthStrings.startSignup,
      isBusy: _busy,
      onPressed: _canSubmit ? _signUp : null,
      child: LabeledTextField(
        label: AuthStrings.nicknameLabel,
        hint: AuthStrings.nicknameHint,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.done,
        // 한글은 조합 중 글자가 잠깐 들어오므로 글자 필터는 걸지 않는다.
        inputFormatters: [
          LengthLimitingTextInputFormatter(AuthMetrics.nicknameMaxLength),
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
