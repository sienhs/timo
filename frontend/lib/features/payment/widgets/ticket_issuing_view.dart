import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 결제가 끝나고 티켓이 발행되기를 기다리는 동안 완료 화면을 대신 채우는 연출.
/// 서버가 잔액 차감과 NFT 발행을 체인에 올리는 진짜 기다림이라, 연출이 도는
/// 동안에는 화면에 누를 것을 두지 않고 버튼 자리는 진행 바가 맡는다. 지갑 준비·
/// 양도 결제 연출과 같은 결이다.
class TicketIssuingView extends StatefulWidget {
  const TicketIssuingView({super.key, this.delayed = false});

  /// 기다릴 만큼 기다렸는데도 안 끝났는가. 참이어도 연출은 그대로 돌고 문구와
  /// 진행 바 색만 바뀐다. 나갈 버튼은 이 위젯 밖(`PaymentCompleteScreen`)에서 붙인다.
  final bool delayed;

  /// 너구리가 티켓을 써서 내미는 클립.
  static const asset = 'assets/videos/issuing.mp4';

  @override
  State<TicketIssuingView> createState() => _TicketIssuingViewState();
}

class _TicketIssuingViewState extends State<TicketIssuingView> {
  VideoPlayerController? _controller;
  var _ready = false;

  /// 기다림이 길어졌는가. 참이 되면 안내 문구가 바뀐다.
  var _longWait = false;
  Timer? _hint;

  @override
  void initState() {
    super.initState();
    // 지연 문구로 이미 넘어온 뒤라면 중간 문구를 띄울 이유가 없다.
    if (!widget.delayed) {
      _hint = Timer(PaymentConstants.issuingHintDelay, () {
        if (mounted) setState(() => _longWait = true);
      });
    }
    _play();
  }

  @override
  void dispose() {
    _hint?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  /// 실패하면 [_ready] 가 false 로 남아 영상 자리가 빈 채로 간다. 영상을 못
  /// 읽었다고 발행까지 붙잡을 이유는 없다.
  Future<void> _play() async {
    final controller = VideoPlayerController.asset(TicketIssuingView.asset);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      // 자산에 소리 트랙이 없지만 끄고 간다. 영상을 갈아 끼웠을 때 결제를 막
      // 마친 사람에게 예고 없이 소리가 나가는 일은 없어야 한다.
      await controller.setVolume(0);
      // 되풀이 지점을 놓쳤을 때를 위한 안전장치다. 평소에는 [_onTick] 이
      // 그 전에 앞으로 되감아 클립 끝까지 가지 않는다.
      await controller.setLooping(true);
      controller.addListener(_onTick);
      if (!mounted) return;
      setState(() => _ready = true);
      // 동작 줄이기를 켠 사람에게는 첫 장면만 세워 둔다. 진행 중이라는 사실은
      // 아래 진행 바가 계속 알린다.
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
      await controller.play();
    } catch (_) {
      // 자리를 비워 둔다. 따로 알리지 않는다 — 발행은 그대로 진행 중이고,
      // 여기서 오류를 띄우면 발행이 잘못된 것처럼 읽힌다.
    }
  }

  /// 티켓을 다 쓰고 내미는 장면 앞에서 되감는다. 클립을 통째로 돌리면 발행이
  /// 아직인데도 완성된 티켓이 주기적으로 나타난다.
  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    if (value.position >= PaymentConstants.issuingClipLoopEnd) {
      _controller?.seekTo(Duration.zero);
    }
  }

  /// 안쪽 여백. 가운데 정렬 계산에도 쓰여 상수로 둔다.
  static const _padding = EdgeInsets.fromLTRB(16, 24, 16, 32);

  /// 지연이면 지연 문구, 아니면 기다린 시간에 따라 둘 중 하나.
  String get _description {
    if (widget.delayed) return PaymentConstants.issueDelayedDescription;
    return _longWait
        ? PaymentConstants.issuingDescriptionLong
        : PaymentConstants.issuingDescription;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // 글자 크기를 키운 기기에서는 클립과 문구만으로 화면이 넘친다. 들어가면
    // 가운데로 모으고, 넘치면 스크롤로 흘린다.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: _padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - _padding.vertical,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Clip(controller: _ready ? _controller : null),
              const SizedBox(height: 32),
              Semantics(
                liveRegion: true,
                label: widget.delayed
                    ? PaymentConstants.issueDelayedSemantics
                    : PaymentConstants.issuingCeremonySemantics,
                child: Column(
                  children: [
                    Text(
                      widget.delayed
                          ? PaymentConstants.issueDelayedTitle
                          : PaymentConstants.issuingCeremonyTitle,
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _description,
                      style: textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // 화면 맨 아래가 아니라 문구 바로 밑에 둔다. 눈이 가는 곳은 가운데라
              // 저 아래 얇은 막대는 기다리는 사람 눈에 안 들어온다.
              SizedBox(
                width: PaymentConstants.issuingProgressWidth,
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  child: LinearProgressIndicator(
                    minHeight: PaymentConstants.issuingProgressHeight,
                    backgroundColor: AppColors.border,
                    // 색 하나로 같은 화면이 아니라는 것을 알린다. 문구만 바꾸면
                    // 두 화면이 거의 같아 보여 무엇이 달라졌는지 지나치기 쉽다.
                    color: widget.delayed
                        ? PaymentColors.delayedProgress
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 영상 자리. 준비되기 전과 못 읽었을 때는 비워 둔다. 자리는 [AspectRatio] 로
/// 잡아 둬 영상이 늦게 떠도 아래 문구가 밀리지 않는다. 마스코트로 채우지 않는다
/// — 따봉 든 너구리는 발행이 끝났다는 신호라 두 가지를 뜻하게 된다. 테두리도
/// 배경도 두르지 않는다 — 자산의 배경이 흰색이라 카드를 주면 그 카드가 떠 보인다.
class _Clip extends StatelessWidget {
  const _Clip({required this.controller});

  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final player = controller;

    return AspectRatio(
      aspectRatio: PaymentConstants.issuingClipAspectRatio,
      child: player == null
          ? const SizedBox.shrink()
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
