import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_logo.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';

/// 가입 직후 지갑을 준비하는 동안 보여주는 화면. 영상이 끝나면 완료 화면으로
/// 저절로 넘어간다. 지갑은 서버가 가입 요청 안에서 만들므로 기다리는 것은
/// 연출뿐이다. 영상을 못 읽거나 끝을 알리지 못해도 타이머로 넘어가 갇히지 않는다.
class WalletCreatingScreen extends StatefulWidget {
  const WalletCreatingScreen({super.key});

  /// 너구리가 지갑에 버섯을 담는 클립.
  static const asset = 'assets/videos/wallet_creating.mp4';

  @override
  State<WalletCreatingScreen> createState() => _WalletCreatingScreenState();
}

class _WalletCreatingScreenState extends State<WalletCreatingScreen> {
  VideoPlayerController? _controller;
  Timer? _maxWait;
  var _ready = false;
  var _left = false;

  @override
  void initState() {
    super.initState();
    _maxWait = Timer(AuthMetrics.walletCeremonyMaxWait, _goComplete);
    _play();
  }

  @override
  void dispose() {
    _maxWait?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    final controller = VideoPlayerController.asset(WalletCreatingScreen.asset);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      // 자산에는 소리 트랙이 없지만 끄고 간다. 영상을 갈아 끼웠을 때 가입을
      // 막 마친 사람에게 예고 없이 소리가 나가는 일은 없어야 한다.
      await controller.setVolume(0);
      await controller.setPlaybackSpeed(AuthMetrics.walletClipSpeed);
      controller.addListener(_onTick);
      if (!mounted) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      // _ready 가 false 로 남아 마스코트가 그려진다. 영상 없이 6초를 세울
      // 이유는 없으니 기다리는 시간만 줄여 잡는다.
      if (!mounted) return;
      _maxWait?.cancel();
      _maxWait = Timer(AuthMetrics.walletCeremonyFallback, _goComplete);
    }
  }

  /// 끝까지 재생됐으면 완료 화면으로. 반복 재생이 아니라 마지막 프레임에서 멈춘다.
  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    if (value.position >= value.duration) _goComplete();
  }

  /// 여러 갈래(재생 끝·안전 타이머·읽기 실패)에서 불리므로 한 번만 통과시킨다.
  void _goComplete() {
    if (_left || !mounted) return;
    _left = true;
    _maxWait?.cancel();
    Navigator.pushReplacementNamed(context, AppRoutes.signupComplete);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const side = AuthMetrics.pagePadding;

    return PopScope(
      // 가입은 이미 끝났고 되돌릴 것이 없다. 뒤로가기로 닉네임 화면에 돌아가면
      // 같은 초안으로 다시 가입을 시도하게 된다.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(side, 24, side, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: TimoLogo(height: AuthMetrics.completeLogoHeight),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Clip(controller: _ready ? _controller : null),
                        const SizedBox(height: 32),
                        Semantics(
                          liveRegion: true,
                          label: AuthStrings.walletCreatingSemantics,
                          child: Column(
                            children: [
                              Text(
                                AuthStrings.walletCreatingTitle,
                                style: textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AuthStrings.walletCreatingSubtitle,
                                style: textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 버튼이 서던 자리. 누를 것이 없는 화면이라 진행 중임을 대신 알린다.
                const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: AppColors.surfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 영상 자리. 준비 전과 못 읽었을 때는 마스코트로 같은 자리를 채워 아래 문구가
/// 출렁이지 않게 한다. 자산 배경이 페이지와 같은 흰색이라 테두리도 배경도
/// 두르지 않는다(`docs/video-assets.md`).
class _Clip extends StatelessWidget {
  const _Clip({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final player = controller;

    return AspectRatio(
      aspectRatio: AuthMetrics.walletClipAspectRatio,
      child: player == null
          ? const Center(
              child: TimoMascot.cheer(
                size: AuthMetrics.completeIllustrationSize,
              ),
            )
          : FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: player.value.size.width,
                height: player.value.size.height,
                child: VideoPlayer(player),
              ),
            ),
    );
  }
}
