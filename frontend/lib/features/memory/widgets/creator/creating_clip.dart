import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../constants.dart';
import '../../motion/motion_tokens.dart';

/// 소장품을 만드는 동안 보여주는 클립. 앞부분(만드는 장면)을 되풀이하다가,
/// 제작이 끝나면 끝까지 흘러가 완성된 선물을 든 마지막 장면에서 멈춘다.
///
/// 가입 직후 지갑 연출([WalletCreatingScreen])과 같은 방식이다 — 자산의 배경을
/// 페이지와 같은 흰색으로 눌러 두고(`docs/video-assets.md`), 화면 쪽에서는
/// 테두리도 카드도 두르지 않는다. 남은 가장자리 색까지 지우려고 바깥을 흰색으로
/// 흐리게 지운다. 그래야 "영상 한 칸" 이 아니라 종이 위에 놓인 장면으로 읽힌다.
///
/// 읽는 동안과 읽지 못했을 때는 **아무것도 그리지 않는다.** 자리만 비워 둔다 —
/// 대신 그림을 세우면 영상이 준비되는 순간 두 그림이 겹쳐 보이고, 무엇을
/// 기다리는지는 아래 문구가 이미 말한다.
class CreatingClip extends StatefulWidget {
  const CreatingClip({super.key, required this.done, required this.size});

  /// 제작이 끝났는가. 참이 되면 클립이 마지막 장면까지 간다.
  final bool done;
  final double size;

  static const asset = 'assets/videos/creating.mp4';

  @override
  State<CreatingClip> createState() => _CreatingClipState();
}

class _CreatingClipState extends State<CreatingClip> {
  VideoPlayerController? controller;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(CreatingClip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 되풀이를 풀면 감시자가 더는 앞으로 되감지 않아 끝 장면까지 흘러간다.
    if (!oldWidget.done && widget.done) controller?.play();
  }

  @override
  void dispose() {
    controller?.removeListener(onTick);
    controller?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final player = VideoPlayerController.asset(CreatingClip.asset);
    controller = player;
    try {
      await player.initialize();
      if (!mounted) return;
      // 자산에 소리 트랙이 없어도 꺼 둔다. 영상을 갈아 끼웠을 때 만드는 중인
      // 사람에게 예고 없이 소리가 나가지 않게.
      await player.setVolume(0);
      player.addListener(onTick);
      if (!mounted) return;
      setState(() => ready = true);
      // 동작 줄이기를 켠 사람에게는 한 장면만 세워 둔다.
      if (Motion.reduced(context)) {
        await player.seekTo(
          widget.done ? player.value.duration : CreatorLayout.clipMakingEnd,
        );
        return;
      }
      await player.play();
    } catch (_) {
      // ready 가 false 로 남아 선물 상자가 그려진다.
    }
  }

  void onTick() {
    final value = controller?.value;
    if (value == null || !value.isInitialized) return;
    if (widget.done) {
      // 마지막 장면에서 멈춘다. 되풀이하면 완성이 지나가 버린다.
      if (value.position >= value.duration) controller?.pause();
      return;
    }
    if (value.position >= CreatorLayout.clipMakingEnd) {
      controller?.seekTo(Duration.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    // 자리는 잡아 둔다. 영상이 늦게 뜰 때 아래 문구가 밀려 내려가면 화면이 한
    // 번 출렁인다.
    return SizedBox(
      width: widget.size * CreatorLayout.clipWidthFactor,
      child: AspectRatio(
        aspectRatio: CreatorLayout.clipAspect,
        child: !ready || player == null
            ? const SizedBox.shrink()
            : ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const RadialGradient(
                  radius: 0.75,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.72, 1],
                ).createShader(rect),
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: player.value.size.width,
                    height: player.value.size.height,
                    child: VideoPlayer(player),
                  ),
                ),
              ),
      ),
    );
  }
}
