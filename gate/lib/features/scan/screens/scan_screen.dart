import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../constants.dart';
import '../models/gate_target.dart';
import '../models/verification_result.dart';
import '../state/scan_api_scope.dart';
import '../widgets/scan_result_view.dart';
import '../widgets/scan_viewfinder.dart';

/// 검표 화면. 공연을 고른 뒤 보는 화면이다.
///
/// 카메라가 QR 을 읽으면 서버에 검증을 맡기고, 결과를 화면 전체로 보여 준
/// 뒤 다시 읽기로 돌아온다. 화면이 하는 판단은 **"지금 읽어도 되는가"** 하나다 —
/// 검증 중이거나 결과를 보여 주는 동안, 그리고 방금 읽은 것과 같은 QR 은
/// 무시한다. 티켓이 유효한지는 전부 서버가 판단한다.
///
/// 카메라는 결과를 보여 주는 동안에도 끄지 않는다. 다시 켜는 데 0.5~1초가
/// 걸려 줄이 그만큼 밀린다. 결과 화면이 불투명하게 덮으므로 보이지는 않는다.
///
/// 헤더에는 검표 중인 공연([target])이 적힌다. 운영자가 옆 입구의 단말과
/// 바꿔 들었을 때 어느 공연을 받고 있는지 한눈에 알아야 한다. [onChangeTarget]
/// 은 헤더의 '공연 변경' 버튼이 부른다 — 어디로 가서 고르는지는 앱이 안다.
///
/// [trailing] 은 헤더 맨 오른쪽(로그아웃 버튼). 이 화면은 인증을 모른다.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.target,
    this.onChangeTarget,
    this.trailing,
  });

  final GateTarget target;
  final VoidCallback? onChangeTarget;
  final Widget? trailing;

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
    final onChangeTarget = widget.onChangeTarget;

    return Scaffold(
      backgroundColor: AppColors.scanBackground,
      // 카메라 화면이라 앱 공통(흰) 앱바 대신 어두운 바를 쓴다. 흰 띠가 위에
      // 붙으면 카메라 영역이 잘려 보이고, 밝은 곳에서 눈이 그쪽으로 끌린다.
      appBar: AppBar(
        backgroundColor: AppColors.scanBackground,
        foregroundColor: AppColors.onScan,
        centerTitle: false,
        titleSpacing: ScanMetrics.horizontalPadding,
        title: _TargetHeader(target: widget.target),
        actions: [
          _TorchButton(controller: _controller),
          if (onChangeTarget != null)
            IconButton(
              tooltip: ScanStrings.changeTarget,
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: onChangeTarget,
            ),
          if (widget.trailing != null) widget.trailing!,
          const SizedBox(width: 4),
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

/// 헤더의 공연 표시. 첫 줄 공연명, 둘째 줄 공연장 · 일시.
class _TargetHeader extends StatelessWidget {
  const _TargetHeader({required this.target});

  final GateTarget target;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitle = target.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          target.concertTitle,
          style: textTheme.titleMedium?.copyWith(color: AppColors.onScan),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.onScanMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// 조준 틀 덮개와 그 아래 안내 패널.
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
            // 보조 안내는 패널에 담아 카메라 화면과 분리한다. 카메라 위에 글자만
            // 얹으면 관람객 옷 색에 따라 읽히다 안 읽히다 한다.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.scanPanel,
                borderRadius: BorderRadius.circular(ScanMetrics.panelRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_android_rounded,
                    size: 20,
                    color: AppColors.onScanMuted,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      ScanStrings.scanDescription,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.onScanMuted,
                      ),
                    ),
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
        padding: const EdgeInsets.only(bottom: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.scanPanel,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 48,
              color: AppColors.onScanMuted,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppColors.onScan),
            ),
          ],
        ),
      ),
    );
  }
}
