import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
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

/// 1/4 기본 정보와 휴대폰 인증.
///
/// 이름과 휴대폰 번호를 한 화면에서 받고, 인증번호 발송이 끝나면 같은 화면 아래에
/// 인증번호 입력 영역을 펼친다. 인증에 성공하면 세 값을 초안에 담아 아이디 화면으로
/// 이동한다. 발송한 뒤 휴대폰 번호를 고치면 기존 인증번호를 폐기하고 다시 요청하게
/// 한다.
class SignupPhoneScreen extends StatefulWidget {
  const SignupPhoneScreen({
    super.key,
    this.draft = const SignupDraft(),
    this.api,
  });

  final SignupDraft draft;
  final AuthApi? api;

  @override
  State<SignupPhoneScreen> createState() => _SignupPhoneScreenState();
}

class _SignupPhoneScreenState extends State<SignupPhoneScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();

  Timer? _codeTimer;
  Timer? _resendTimer;
  var _remaining = Duration.zero;
  var _codeRequested = false;
  var _expired = false;
  var _showExpiredError = false;
  var _verificationBlocked = false;
  var _resendReady = false;
  var _busy = false;
  var _sentPhoneNumber = '';
  String? _verificationTicket;
  String? _codeError;

  AuthApi get _api => widget.api ?? AuthApiScope.of(context);
  String get _name => _nameController.text.trim();
  String get _phoneNumber => SignupValidators.digitsOnly(_phoneController.text);

  bool get _nameValid => SignupValidators.isValidName(_name);
  bool get _phoneValid => SignupValidators.isValidPhone(_phoneNumber);
  bool get _verified => _verificationTicket != null;
  bool get _canRequest => !_busy && _nameValid && _phoneValid;
  bool get _canContinue =>
      !_busy && _verified && _nameValid && _phoneNumber == _sentPhoneNumber;
  bool get _canVerify =>
      !_busy &&
      !_expired &&
      !_verificationBlocked &&
      _nameValid &&
      _phoneNumber == _sentPhoneNumber &&
      SignupValidators.isValidCode(_codeController.text);

  String? get _nameHelper {
    if (_name.isEmpty || _nameValid) return null;
    return AuthStrings.nameRule;
  }

  String? get _fieldError {
    if (_verificationBlocked) return _codeError;
    if (_expired && _showExpiredError) return AuthStrings.codeExpired;
    return _codeError;
  }

  @override
  void dispose() {
    _codeTimer?.cancel();
    _resendTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCodeCountdown(Duration validFor) {
    _codeTimer?.cancel();
    _remaining = validFor;
    _expired = false;
    _showExpiredError = false;
    _verificationBlocked = false;
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final next = _remaining - const Duration(seconds: 1);
        if (next <= Duration.zero) {
          _expireCode();
        } else {
          _remaining = next;
        }
      });
    });
  }

  void _expireCode() {
    _remaining = Duration.zero;
    _expired = true;
    _showExpiredError = true;
    _codeError = null;
    _resendReady = true;
    _codeTimer?.cancel();
    _resendTimer?.cancel();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendReady = false;
    _resendTimer = Timer(AuthMetrics.resendCooldown, () {
      if (!mounted) return;
      setState(() => _resendReady = true);
    });
  }

  void _onPhoneChanged(String _) {
    final changedAfterSend = _codeRequested && _phoneNumber != _sentPhoneNumber;
    setState(() {
      if (changedAfterSend) _clearRequestedCode();
    });
  }

  void _clearRequestedCode() {
    _codeTimer?.cancel();
    _resendTimer?.cancel();
    _codeController.clear();
    _remaining = Duration.zero;
    _codeRequested = false;
    _expired = false;
    _showExpiredError = false;
    _verificationBlocked = false;
    _resendReady = false;
    _sentPhoneNumber = '';
    _verificationTicket = null;
    _codeError = null;
  }

  Future<void> _requestCode() async {
    final phoneNumber = _phoneNumber;
    setState(() => _busy = true);

    final Duration validFor;
    try {
      validFor = await _api.requestVerificationCode(phoneNumber);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, _sendFailureMessage(e));
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeRequested = true;
      _sentPhoneNumber = phoneNumber;
      _verificationTicket = null;
      _codeError = null;
      _startCodeCountdown(validFor);
      _startResendCooldown();
    });
    showSuccessSnackBar(context, AuthStrings.codeSent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  Future<void> _resend() async {
    setState(() => _busy = true);

    final Duration validFor;
    try {
      validFor = await _api.requestVerificationCode(_sentPhoneNumber);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, _sendFailureMessage(e));
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _codeController.clear();
      _verificationTicket = null;
      _codeError = null;
      _startCodeCountdown(validFor);
      _startResendCooldown();
    });
    showSuccessSnackBar(context, AuthStrings.codeResent);
    _codeFocus.requestFocus();
  }

  Future<void> _verify() async {
    final code = _codeController.text;
    setState(() {
      _busy = true;
      _codeError = null;
    });

    final String? ticket;
    try {
      ticket = await _api.verifyCode(phoneNumber: _sentPhoneNumber, code: code);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showVerifyFailure(e);
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ticket == null) _codeError = AuthStrings.codeMismatch;
    });
    if (ticket == null) return;

    setState(() {
      _verificationTicket = ticket;
      _codeTimer?.cancel();
      _resendTimer?.cancel();
    });
    _goToUsername();
  }

  void _goToUsername() {
    final ticket = _verificationTicket;
    if (ticket == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.signupUsername,
      arguments: widget.draft.copyWith(
        name: _name,
        phoneNumber: _sentPhoneNumber,
        verificationTicket: ticket,
      ),
    );
  }

  void _showVerifyFailure(ApiException e) {
    final serverSaysExpired =
        e.exceptionName == AuthServerErrors.smsCodeNotFound;
    final aboutThisInput = (e.status ?? 0) ~/ 100 == 4;
    setState(() {
      _busy = false;
      if (serverSaysExpired) {
        _expireCode();
      } else if (aboutThisInput) {
        final attemptsExceeded =
            e.exceptionName == AuthServerErrors.smsAttemptExceeded;
        _codeError = attemptsExceeded ? AuthStrings.attemptExceeded : e.message;
        if (attemptsExceeded) {
          _verificationBlocked = true;
          _resendReady = true;
          _resendTimer?.cancel();
        }
      }
    });
    if (!aboutThisInput) showErrorSnackBar(context, e.message);
  }

  String _sendFailureMessage(ApiException e) {
    return switch (e.exceptionName) {
      AuthServerErrors.smsSendLimitExceeded => AuthStrings.sendLimitExceeded,
      AuthServerErrors.smsSendFailed => AuthStrings.sendFailed,
      _ => e.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    final canResend = !_busy && _resendReady;
    return SignupStepPage(
      step: 1,
      title: AuthStrings.phoneTitle,
      subtitle: AuthStrings.phoneSubtitle,
      buttonLabel: _verified
          ? AuthStrings.next
          : _codeRequested
          ? AuthStrings.verify
          : AuthStrings.requestCode,
      isBusy: _busy,
      onPressed: _verified
          ? (_canContinue ? _goToUsername : null)
          : _codeRequested
          ? (_canVerify ? _verify : null)
          : (_canRequest ? _requestCode : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledTextField(
            label: AuthStrings.nameLabel,
            hint: AuthStrings.nameHint,
            controller: _nameController,
            autofocus: true,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              LengthLimitingTextInputFormatter(AuthMetrics.nameMaxLength),
            ],
            helperText: _nameHelper,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _phoneFocus.requestFocus(),
          ),
          const SizedBox(height: 20),
          LabeledTextField(
            label: AuthStrings.phoneLabel,
            hint: AuthStrings.phoneHint,
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            textInputAction: _codeRequested
                ? TextInputAction.next
                : TextInputAction.done,
            inputFormatters: const [PhoneNumberInputFormatter()],
            onChanged: _onPhoneChanged,
            onSubmitted: (_) {
              if (_codeRequested) {
                _codeFocus.requestFocus();
              } else if (_canRequest) {
                _requestCode();
              }
            },
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _verified
                ? const _VerificationComplete()
                : !_codeRequested
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey('verification-code'),
                    padding: const EdgeInsets.only(top: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LabeledTextField(
                          label: AuthStrings.codeLabel,
                          hint: AuthStrings.codeHint,
                          controller: _codeController,
                          focusNode: _codeFocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(
                              AuthMetrics.codeLength,
                            ),
                          ],
                          errorText: _fieldError,
                          onChanged: (_) => setState(() {
                            _showExpiredError = false;
                            if (!_verificationBlocked) _codeError = null;
                          }),
                          onSubmitted: (_) {
                            if (_canVerify) _verify();
                          },
                          suffixIcon: _CountdownLabel(remaining: _remaining),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              disabledForegroundColor: AppColors.textDisabled,
                            ),
                            onPressed: canResend ? _resend : null,
                            child: const Text(AuthStrings.resendCode),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VerificationComplete extends StatelessWidget {
  const _VerificationComplete();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('verification-complete'),
      padding: EdgeInsets.only(top: 20),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            AuthStrings.verificationComplete,
            style: TextStyle(
              color: AppColors.primaryPressed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownLabel extends StatelessWidget {
  const _CountdownLabel({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final clock = formatCountdown(remaining);
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Center(
        widthFactor: 1,
        child: Text(
          clock,
          semanticsLabel: AuthStrings.remainingTime(clock),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.accent,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
