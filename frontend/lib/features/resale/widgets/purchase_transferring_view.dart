import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/timo_mascot.dart';
import '../constants.dart';

/// 결제 요청을 보내고 응답을 기다리는 동안 구매 화면을 채우는 연출. 서버가
/// 온체인 체결까지 끝내고 답하므로 이 기다림은 진짜 일이고, 그래서 최소 표시
/// 시간을 두지 않는다. 타이머도 화면 전환도 없다 — 언제 걷히는지는 요청을
/// 보낸 `ListingPurchaseScreen` 이 정한다.
class PurchaseTransferringView extends StatefulWidget {
  const PurchaseTransferringView({super.key});

  /// 너구리가 편지를 전하는 클립.
  static const asset = 'assets/videos/transferring.mp4';

  @override
  State<PurchaseTransferringView> createState() =>
      _PurchaseTransferringViewState();
}

class _PurchaseTransferringViewState extends State<PurchaseTransferringView> {
  VideoPlayerController? _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 실패하면 [_ready] 가 false 로 남아 마스코트가 대신 그려진다. 영상을 못
  /// 읽었다고 결제까지 붙잡을 이유는 없다.
  Future<void> _play() async {
    final controller = VideoPlayerController.asset(
      PurchaseTransferringView.asset,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      // 자산에 소리 트랙이 없지만 끄고 간다. 영상을 갈아 끼웠을 때 결제 중인
      // 사람에게 예고 없이 소리가 나가는 일은 없어야 한다.
      await controller.setVolume(0);
      // 기다림이 얼마나 갈지 모른다. 체인이 더디면 클립보다 오래 걸린다.
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      // 마스코트가 대신 선다. 따로 알리지 않는다 — 결제는 그대로 진행 중이고,
      // 여기서 오류를 띄우면 결제가 잘못된 것처럼 읽힌다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ResaleMetrics.horizontalPadding,
        24,
        ResaleMetrics.horizontalPadding,
        32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Clip(controller: _ready ? _controller : null),
                  const SizedBox(height: 32),
                  Semantics(
                    liveRegion: true,
                    label: ResaleStrings.transferringSemantics,
                    child: Column(
                      children: [
                        Text(
                          ResaleStrings.transferringTitle,
                          style: textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ResaleStrings.transferringSubtitle,
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
          // 결제 버튼이 서던 자리. 누를 것이 없는 동안 진행 중임을 대신 알린다.
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: AppColors.surfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 영상 자리. 준비되기 전과 못 읽었을 때는 마스코트로 같은 자리를 채워 아래
/// 문구가 출렁이지 않게 한다. 테두리도 배경도 두르지 않는다 — 자산의 배경이
/// 흰색이라(`docs/video-assets.md`) 카드를 주면 그 카드가 떠 보이고, 화면을
/// 흰 바탕으로 두는 것도 같은 이유다.
class _Clip extends StatelessWidget {
  const _Clip({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final player = controller;

    return AspectRatio(
      aspectRatio: ResaleMetrics.transferClipAspectRatio,
      child: player == null
          ? const Center(
              child: TimoMascot.cheer(size: ResaleMetrics.transferMascotSize),
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
