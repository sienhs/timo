import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 결제가 끝나고 티켓이 발행되기를 기다리는 동안 완료 화면을 대신 채우는 연출.
///
/// **이 기다림은 진짜 일이다.** 서버가 잔액 차감과 NFT 발행을 체인에 올리는
/// 중이고, 끝나야 티켓이 생긴다. 그래서 이 연출이 도는 동안에는 화면에 누를
/// 것을 두지 않는다 — 티켓도 없는데 '티켓 보러 가기'를 내어 주면 빈 목록으로
/// 보내는 셈이고, '홈으로'는 결과를 못 본 채 화면을 뜨게 만든다. 버튼이 서던
/// 자리는 진행 바가 대신 맡는다.
///
/// 지갑 준비([WalletCreatingScreen])·양도 결제([PurchaseTransferringView])와
/// 같은 결이다. 흰 바탕에 클립만 놓고, 무엇을 기다리는지는 아래 문구가 말한다.
class TicketIssuingView extends StatefulWidget {
  const TicketIssuingView({super.key, this.delayed = false});

  /// 기다릴 만큼 기다렸는데도 안 끝났는가.
  ///
  /// 참이어도 연출은 그대로 돈다 — 발행은 정말로 진행 중이라 멈춘 그림을
  /// 세울 이유가 없다. 문구와 진행 바 색만 바뀌고, 화면을 뜰 수 있도록 이
  /// 위젯 **밖에서** 버튼을 붙인다([PaymentCompleteScreen]).
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

  /// 실패하면 [_ready] 가 false 로 남아 마스코트가 대신 그려진다.
  ///
  /// 영상을 못 읽었다고 발행까지 붙잡을 이유는 없다. 결제는 이미 끝났고, 이
  /// 위젯이 하는 일은 그동안 무슨 일이 벌어지는지 보여 주는 것뿐이다.
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
      // 마스코트가 대신 선다. 따로 알리지 않는다 — 발행은 그대로 진행 중이고,
      // 여기서 오류를 띄우면 발행이 잘못된 것처럼 읽힌다.
    }
  }

  /// 티켓을 다 쓰고 내미는 장면 앞에서 되감는다.
  ///
  /// 기다림이 얼마나 갈지 모르니 되풀이는 해야 하는데, 클립을 통째로 돌리면
  /// 발행이 아직인데도 완성된 티켓이 주기적으로 나타난다.
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

    // 글자 크기를 키운 기기에서는 클립과 문구만으로 화면이 넘친다(지연이면
    // 아래에 버튼까지 선다). 들어가면 가운데로 모으고, 넘치면 스크롤로 흘린다 —
    // 둘 중 하나를 포기하면 잘리거나, 늘 위쪽에 붙는다.
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
              // 버튼이 서던 화면 맨 아래가 아니라 문구 바로 밑에 둔다. 눈이 가는
              // 곳은 가운데(클립과 문구)라, 저 아래 얇은 막대는 기다리는 사람
              // 눈에 안 들어온다 — 이 화면은 최대 2분을 붙잡아 두므로 진행 중인
              // 표시가 한 덩어리 안에 있어야 한다.
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

/// 영상 자리. 준비되기 전과 못 읽었을 때는 **비워 둔다.**
///
/// 자리는 [AspectRatio] 로 잡아 둔다. 비우기만 하고 높이를 놓으면 영상이 늦게
/// 뜰 때 아래 문구가 밀려 내려가 화면이 한 번 출렁인다.
///
/// 마스코트로 채우지 않는다. 따봉 든 너구리는 이 흐름에서 **발행이 끝났다는
/// 신호**로 쓰고 있어([PaymentCompleteScreen] 의 결과 그림), 기다리는 화면에
/// 세우면 같은 그림이 두 가지를 뜻하게 된다. 무엇을 기다리는지는 아래 문구와
/// 진행 바가 이미 말한다.
///
/// 테두리도 배경도 두르지 않는다. 자산의 배경을 흰색으로 눌러 두어서
/// (`docs/video-assets.md` 참고) 너구리가 화면 위에 바로 놓인 것처럼 보인다.
/// 여기에 카드나 모서리를 주면 그 카드가 대신 떠 보인다. 연출이 도는 동안
/// 화면을 흰 바탕으로 두는 것도 같은 이유다 — 완료 화면의 연회색 위에 올리면
/// 흰 사각형이 드러난다.
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
