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
import '../utils/signup_validators.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/signup_step_page.dart';

/// 전화번호 화면이 인증번호 화면에 넘기는 라우트 인자.
///
/// 초안에 더해 **인증번호 유효 시간**을 넘긴다. 서버가 발송 응답에 유효 시간을
/// 실어 주므로, 화면이 임의로 정하지 않고 그 값으로 남은 시간을 센다.
class SignupCodeArguments {
  const SignupCodeArguments({required this.draft, required this.validFor});

  final SignupDraft draft;
  final Duration validFor;
}

/// 1/5 본인인증 — 인증번호 입력. 전화번호 화면과 같은 제목·단계를 쓴다.
///
/// 입력칸 오른쪽에 남은 시간이 흐른다. 0 이 되면(또는 서버가 만료라고 하면) 칸
/// 아래 만료 문구가 뜨고 하단 버튼이 '인증번호 다시 받기' 로 바뀐다. 다시 받으면
/// 입력이 비워지고 새 유효 시간으로 다시 센다.
///
/// 번호가 틀리면 칸 아래 오류 문구를 띄우고, 다시 타이핑하면 지운다. 맞으면
/// 서버가 준 인증 티켓을 초안에 담아 이름 화면으로 간다.
class SignupCodeScreen extends StatefulWidget {
  const SignupCodeScreen({
    super.key,
    required this.draft,
    this.validFor = AuthMetrics.codeValidity,
    this.api,
  });

  final SignupDraft draft;

  /// 이 화면이 열릴 때 인증번호가 유효한 시간. 전화번호 화면이 서버 응답 값을
  /// 넘겨준다. 안 넘기면(화면 단위 테스트, 딥링크) 서버와 같은 기본값.
  final Duration validFor;

  /// 직접 넘기면 그걸 쓰고(테스트), 안 넘기면 [AuthApiScope] 에서 받는다(앱).
  final AuthApi? api;

  @override
  State<SignupCodeScreen> createState() => _SignupCodeScreenState();
}

class _SignupCodeScreenState extends State<SignupCodeScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  late Duration _remaining;
  var _expired = false;
  var _busy = false;
  String? _errorText;

  AuthApi get _api => widget.api ?? AuthApiScope.of(context);

  bool get _canSubmit =>
      !_busy && !_expired && SignupValidators.isValidCode(_controller.text);

  /// 칸 아래 문구. 만료가 최우선이고, 만료 전에는 틀림·서버 안내.
  String? get _fieldError => _expired ? AuthStrings.codeExpired : _errorText;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.validFor);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// [validFor] 부터 1초씩 줄여 0 에서 만료시킨다.
  ///
  /// 시계(DateTime.now)를 읽지 않고 틱 수로 세는 이유는 테스트에서 가짜 시간을
  /// pump 로 돌려 검사할 수 있게 하기 위해서다. 3분 동안 1초씩 어긋날 일은 없다.
  void _startCountdown(Duration validFor) {
    _timer?.cancel();
    _remaining = validFor;
    _expired = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining <= Duration.zero) _expire();
      });
    });
  }

  /// 인증번호를 더 쓸 수 없게 잠근다. 세던 시간을 멈추고 다시 받기로 유도한다.
  void _expire() {
    _timer?.cancel();
    _remaining = Duration.zero;
    _expired = true;
  }

  Future<void> _verify() async {
    final code = _controller.text;
    setState(() {
      _busy = true;
      _errorText = null;
    });

    final String? ticket;
    try {
      ticket = await _api.verifyCode(
        phoneNumber: widget.draft.phoneNumber,
        code: code,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFailure(e);
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ticket == null) _errorText = AuthStrings.codeMismatch;
    });
    if (ticket == null) return;
    // 인증이 끝났으니 시간을 더 셀 이유가 없다. 아래에 깔린 이 화면이 계속 틱을
    // 돌리면 다음 화면들에서 매초 리빌드가 생긴다.
    _timer?.cancel();
    // 티켓은 가입 요청에 같이 보내야 하므로 초안에 담아 끝까지 들고 간다.
    Navigator.pushNamed(
      context,
      AppRoutes.signupName,
      arguments: widget.draft.copyWith(verificationTicket: ticket),
    );
  }

  /// 서버가 이 입력에 대해 알려준 것(4xx)은 칸 아래에, 서버에 닿지 못한 실패나
  /// 서버 오류는 스낵바에 보여준다. 서버가 만료라고 하면 우리 시계가 조금
  /// 남았어도 만료 상태로 맞춘다.
  void _showFailure(ApiException e) {
    final serverSaysExpired =
        e.exceptionName == AuthServerErrors.smsCodeNotFound;
    final aboutThisInput = (e.status ?? 0) ~/ 100 == 4;
    setState(() {
      _busy = false;
      if (serverSaysExpired) {
        _expire();
      } else if (aboutThisInput) {
        _errorText = e.message;
      }
    });
    if (!aboutThisInput) showErrorSnackBar(context, e.message);
  }

  /// 만료 뒤 '인증번호 다시 받기'. 새 유효 시간으로 다시 세고 입력을 비운다.
  /// 발송 제한(1분 안에 재요청)은 유효 시간(3분)보다 짧아 보통 걸리지 않는다.
  Future<void> _resend() async {
    setState(() => _busy = true);

    final Duration validFor;
    try {
      validFor = await _api.requestVerificationCode(widget.draft.phoneNumber);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnackBar(context, e.message);
      return;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _errorText = null;
      _controller.clear();
      _startCountdown(validFor);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SignupStepPage(
      step: 1,
      title: AuthStrings.verifyTitle,
      subtitle: AuthStrings.verifySubtitle,
      buttonLabel: _expired ? AuthStrings.resendCode : AuthStrings.verify,
      isBusy: _busy,
      onPressed: _expired
          ? (_busy ? null : _resend)
          : (_canSubmit ? _verify : null),
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
        errorText: _fieldError,
        onChanged: (_) => setState(() => _errorText = null),
        onSubmitted: (_) {
          if (_canSubmit) _verify();
        },
        suffixIcon: _CountdownLabel(remaining: _remaining),
      ),
    );
  }
}

/// 입력칸 안 오른쪽 끝의 남은 시간 (`02:59`). 만료되면 `00:00` 에서 멈춘다.
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
            // 숫자 폭을 고정해 초가 바뀔 때 글자가 좌우로 흔들리지 않게 한다.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
