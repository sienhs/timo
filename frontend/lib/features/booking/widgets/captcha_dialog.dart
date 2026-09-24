import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/server_errors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dialog_frame.dart';
import '../constants.dart';
import '../data/booking_api.dart';
import '../models/captcha_challenge.dart';
import '../state/booking_api_scope.dart';

/// 예매에 들어가기 전 한 번 푸는 보안문자 창. 구역 화면 위에 뜬다. 통과했으면 true.
///
/// 창 바깥을 눌러도 닫히지 않는다. 닫기·뒤로 가기는 예매를 그만둔 것이라 false 다.
Future<bool> showCaptchaDialog(
  BuildContext context, {
  required int concertId,
}) async {
  final passed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CaptchaDialog(concertId: concertId),
  );
  return passed ?? false;
}

/// 정답은 서버만 알고, 이 창은 그림을 보여 주고 입력값을 보낼 뿐이다. 키는 확인
/// 한 번에 폐기되므로 실패하면 곧바로 새 문제를 받는다.
class _CaptchaDialog extends StatefulWidget {
  const _CaptchaDialog({required this.concertId});

  /// 통과 기록을 남길 공연. 서버는 공연마다 따로 통과를 센다.
  final int concertId;

  @override
  State<_CaptchaDialog> createState() => _CaptchaDialogState();
}

class _CaptchaDialogState extends State<_CaptchaDialog> {
  late final BookingApi _api;
  final _input = TextEditingController();

  CaptchaChallenge? _challenge;
  bool _issuing = false;
  bool _verifying = false;

  /// 입력칸 아래 빨간 문구. [_messageOf] 가 고른다.
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = BookingApiScope.of(context);
    _issue();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _challenge != null &&
      !_issuing &&
      !_verifying &&
      _input.text.trim().isNotEmpty;

  /// 새 문제를 받는다. [keepError] 는 확인에 실패한 직후라 그 사유를 남겨 둘 때다.
  Future<void> _issue({bool keepError = false}) async {
    setState(() {
      _issuing = true;
      if (!keepError) _error = null;
      _input.clear();
    });
    try {
      final challenge = await _api.issueCaptcha();
      if (!mounted) return;
      setState(() => _challenge = challenge);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _challenge = null;
        _error = _messageOf(e);
      });
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }

  /// 보안문자 실패는 서버 문구 대신 앱 문구를 쓴다. 그 밖의 실패(인터넷 끊김 등)는
  /// [ApiException] 이 이미 고른 문구 그대로다.
  static String _messageOf(ApiException e) => switch ((
    e.exceptionName,
    e.status,
  )) {
    (BookingServerErrors.captchaMismatch, _) => BookingStrings.captchaMismatch,
    (BookingServerErrors.captchaKeyNotFound, _) =>
      BookingStrings.captchaExpired,
    (BookingServerErrors.captchaKeyOwnerMismatch, _) =>
      BookingStrings.captchaRetype,
    (_, 429) => BookingStrings.captchaTooMany,
    (_, 502) => BookingStrings.captchaUnavailable,
    _ => e.message,
  };

  Future<void> _submit() async {
    final challenge = _challenge;
    if (challenge == null || !_canSubmit) return;

    setState(() => _verifying = true);
    try {
      await _api.verifyCaptcha(
        concertId: widget.concertId,
        captchaKey: challenge.captchaKey,
        value: _input.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = _messageOf(e);
      });
    }
    // 오답이든 만료든 서버 장애든 이 키는 이미 폐기됐다.
    await _issue(keepError: true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final error = _error;

    // 키보드가 올라오면 Dialog 가 그만큼 비켜 준다. 작은 폰에서는 그래도 모자라
    // 내용을 스크롤로 감싼다.
    return AppDialogFrame(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    BookingStrings.captchaTitle,
                    style: textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                  tooltip: BookingStrings.captchaClose,
                ),
              ],
            ),
            // 닫기 버튼 자리만큼 오른쪽이 좁아지지 않게 본문은 오른쪽 여백을 따로 준다.
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(BookingStrings.captchaGuide, style: textTheme.bodySmall),
                  const SizedBox(height: 14),
                  _CaptchaImage(
                    challenge: _challenge,
                    loading: _issuing,
                    onRefresh: _issuing || _verifying ? null : _issue,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _input,
                    autofocus: true,
                    // 네이버 보안문자는 대소문자가 섞여 나온다(예: 374vK). 대문자
                    // 자판을 먼저 띄우면 소문자를 대문자로 치게 되므로 두지 않고,
                    // 입력값도 바꾸지 않고 보낸다.
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 20,
                    textInputAction: TextInputAction.done,
                    style: textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: BookingStrings.captchaHint,
                      counterText: '',
                      // 칸 테두리만 빨갛게 하고 문구는 아래에 따로 그린다. 칸이
                      // 그리면 오른쪽까지 들여 써져 한 줄에 안 들어간다.
                      error: error == null ? null : const SizedBox.shrink(),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (error != null)
                    Padding(
                      // 왼쪽만 칸 안 글자와 맞춘다(테마 contentPadding 가로 14).
                      padding: const EdgeInsets.only(left: 14, top: 6),
                      child: Text(
                        error,
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    // 다이얼로그 버튼은 화면 하단 버튼보다 낮게 둔다.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: _canSubmit ? _submit : null,
                    child: _verifying
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text(BookingStrings.captchaSubmit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보안문자 그림. 새로 받기 버튼은 옆에 따로 빼지 않고 그림 안 오른쪽 아래에 둔다.
class _CaptchaImage extends StatelessWidget {
  const _CaptchaImage({
    required this.challenge,
    required this.loading,
    required this.onRefresh,
  });

  static const _height = 80.0;

  final CaptchaChallenge? challenge;
  final bool loading;

  /// 받는 중·확인 중에는 null 이라 버튼이 잠긴다.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final challenge = this.challenge;
    final Widget content;
    if (loading) {
      content = const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (challenge == null) {
      // 문제를 못 받았다. 사유는 입력칸 아래에, 다시 받기는 구석 버튼으로 한다.
      content = const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.textSecondary,
      );
    } else {
      content = Image.memory(
        challenge.image,
        // 키마다 새 그림이다. 키로 구분해야 같은 크기 그림끼리도 다시 그린다.
        key: ValueKey(challenge.captchaKey),
        fit: BoxFit.contain,
        height: _height,
        semanticLabel: BookingStrings.captchaImageLabel,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          content,
          Positioned(
            right: 4,
            bottom: 4,
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 20),
              color: AppColors.textSecondary,
              tooltip: BookingStrings.captchaRefresh,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
