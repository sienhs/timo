import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/logout_button.dart';
import '../constants.dart';
import '../models/gate_target.dart';
import '../models/verification_result.dart';
import '../state/scan_api_scope.dart';
import '../widgets/scan_result_view.dart';
import '../widgets/scan_viewfinder.dart';

/// 검표 화면. 로그인한 뒤 보는 유일한 화면이다.
///
/// 카메라가 QR 을 읽으면 서버에 검증을 맡기고, 결과를 화면 전체로 보여 준
/// 뒤 다시 읽기로 돌아온다. 화면이 하는 판단은 **"지금 읽어도 되는가"** 하나다 —
/// 검증 중이거나 결과를 보여 주는 동안, 그리고 방금 읽은 것과 같은 QR 은
/// 무시한다. 티켓이 유효한지는 전부 서버가 판단한다.
///
/// 카메라는 결과를 보여 주는 동안에도 끄지 않는다. 다시 켜는 데 0.5~1초가
/// 걸려 줄이 그만큼 밀린다. 결과 화면이 불투명하게 덮으므로 보이지는 않는다.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.target});

  final GateTarget target;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  bool _verifying = false;
  VerificationResult? _result;
  Timer? _autoDismiss;

  /// 마지막으로 검증한 QR 과 그 시각. 같은 QR 의 중복 인식을 걸러낸다.
  String? _lastPayload;
  DateTime? _lastScannedAt;

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _acceptingScans => !_verifying && _result == null;

  void _onDetect(BarcodeCapture capture) {
    if (!_acceptingScans) return;

    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (payload == null) return;

    final now = DateTime.now();
    if (payload == _lastPayload &&
        _lastScannedAt != null &&
        now.difference(_lastScannedAt!) < ScanMetrics.duplicateWindow) {
      return;
    }
    _lastPayload = payload;
    _lastScannedAt = now;

    _verify(payload);
  }

  Future<void> _verify(String payload) async {
    setState(() => _verifying = true);

    VerificationResult result;
    try {
      result = await ScanApiScope.of(context)
          .verify(payload: payload, target: widget.target);
    } on ApiException catch (e) {
      // 서버에 닿지 못했다. 티켓 상태는 바뀌지 않았으니 다시 스캔하면 된다.
      result = Undetermined(message: e.message);
    }
    if (!mounted) return;

    setState(() {
      _verifying = false;
      _result = result;
    });
    if (result is Admitted) {
      _autoDismiss = Timer(ScanMetrics.admittedHold, _dismissResult);
    }
  }

  void _dismissResult() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
    if (!mounted || _result == null) return;
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: AppColors.scanBackground,
      appBar: AppBar(
        centerTitle: false,
        title: Text(widget.target.concertTitle),
        actions: [
          _TorchButton(controller: _controller),
          const LogoutButton(),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          const _ScanGuide(),
          if (_verifying) const _VerifyingChip(),
          // 결과는 카메라 위에 불투명하게 덮인다. 나타나고 사라질 때만 짧게 섞인다.
          AnimatedSwitcher(
            duration: ScanMetrics.resultFade,
            child: result == null
                ? const SizedBox.shrink()
                : ScanResultView(
                    key: ValueKey(result),
                    result: result,
                    onDismiss: _dismissResult,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 조준 틀 덮개와 그 아래 안내 문구.
class _ScanGuide extends StatelessWidget {
  const _ScanGuide();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ScanViewfinder(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ScanMetrics.horizontalPadding,
        ),
        child: Column(
          children: [
            Text(
              ScanStrings.scanHint,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(color: AppColors.onScan),
            ),
            const SizedBox(height: 12),
            Text(
              ScanStrings.scanDescription,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.onScan),
            ),
          ],
        ),
      ),
    );
  }
}

/// 서버 응답을 기다리는 동안 아래에 뜨는 작은 표시.
///
/// 서버는 3초 안에 답해야 하지만 그 사이 카메라가 멈춘 것처럼 보이면 운영자가
/// 폰을 다시 대라고 한다. "읽었고 확인 중" 임을 보여 준다.
class _VerifyingChip extends StatelessWidget {
  const _VerifyingChip();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.scanOverlay,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onScan,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                ScanStrings.verifying,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.onScan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 손전등 토글. 어두운 야외 게이트에서 관람객 폰 화면이 반사될 때 끈다.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        final torch = state.torchState;
        if (torch == TorchState.unavailable) return const SizedBox.shrink();
        final on = torch == TorchState.on;
        return IconButton(
          tooltip: on ? ScanStrings.torchOff : ScanStrings.torchOn,
          icon: Icon(on ? Icons.flashlight_off : Icons.flashlight_on),
          onPressed: controller.toggleTorch,
        );
      },
    );
  }
}

/// 카메라를 못 열었을 때. 권한 거부는 해결 방법이 다르므로 문구를 가른다.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final message = error.errorCode == MobileScannerErrorCode.permissionDenied
        ? ScanStrings.cameraPermissionDenied
        : ScanStrings.cameraUnavailable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ScanMetrics.horizontalPadding,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: AppColors.onScan),
        ),
      ),
    );
  }
}
