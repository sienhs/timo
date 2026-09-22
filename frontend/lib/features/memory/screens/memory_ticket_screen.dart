import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../data/goods_failure.dart';
import '../data/goods_uploader.dart';
import '../models/memory_ticket.dart';
import '../motion/motion_tokens.dart';
import '../motion/reveal.dart';
import 'memory_page_route.dart';
import 'story_share_screen.dart';
import '../state/goods_api_scope.dart';
import '../state/ticket_store_scope.dart';
import '../state/tilt_setting_scope.dart';
import '../state/viewer_guide_scope.dart';
import '../theme/timo_colors.dart';
import '../utils/palette_extractor.dart';
import '../widgets/ui/aurora_background.dart';
import '../widgets/ui/glass_panel.dart';
import '../widgets/ui/glow_button.dart';
import '../widgets/ui/local_image.dart';
import '../widgets/ui/overlay_service.dart';
import '../widgets/viewer/immersive_video.dart';
import '../widgets/viewer/memory_ticket_card.dart';
import '../widgets/viewer/viewer_guide.dart';

/// 완성된 소장품 한 장을 보는 화면.
///
/// 어두운 무대 테마에서 연다(`stageRoute`). 효과가 어두운 배경에 맞춰 조정돼
/// 있어 밝은 앱 테마 위에 그대로 올리면 빛이 전부 날아간다.
class MemoryTicketScreen extends StatefulWidget {
  const MemoryTicketScreen({
    super.key,
    required this.ticket,
    this.created = false,
    this.onEdit,
  });

  final MemoryTicket ticket;

  /// 방금 만들어 들어왔을 때 참. 완료 안내 한 줄이 더 붙는다.
  final bool created;

  /// 확정 전 소장품을 다시 만들러 가는 길. 어느 공연으로 만드는지는 이 화면이
  /// 모르므로 열어 준 쪽이 넘긴다. 없으면 '다시 만들기' 를 내지 않는다.
  ///
  /// **이 화면의 context 를 받아 쓴다.** 열어 준 화면의 context 를 가둬 두면,
  /// 만들기 화면이 이 화면으로 교체된 뒤에는 그 context 가 죽어 있어 버튼을
  /// 눌러도 아무 일도 일어나지 않는다.
  final void Function(BuildContext context)? onEdit;

  @override
  State<MemoryTicketScreen> createState() => _MemoryTicketScreenState();
}

class _MemoryTicketScreenState extends State<MemoryTicketScreen> {
  /// 확정하면 이 화면이 들고 있는 소장품도 확정본으로 바뀐다.
  late MemoryTicket ticket = widget.ticket;
  bool get created => widget.created;

  @override
  void initState() {
    super.initState();
    // 처음 여는 사람에게만 조작법을 보여준다. 첫 프레임 뒤에 띄워야 화면이
    // 먼저 그려지고 그 위에 안내가 앉는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final guide = ViewerGuideScope.read(context);
      if (guide.seen) return;
      showViewerGuide(context).then((_) => guide.markSeen());
    });
  }

  /// 서버에 올리는 중. 그동안 확정 버튼이 잠긴다 — 두 번 누르면 같은 이미지를
  /// 두 번 올리고, 두 번째 요청은 멱등 키가 같아 서버가 먼저 만든 것을 돌려줄
  /// 뿐이라 올린 만큼이 고아로 남는다.
  bool uploading = false;

  /// 확정 = 서버에 올리기.
  ///
  /// **서버가 받은 뒤에 기기에 저장한다.** 순서가 반대면 "확정했는데 서버에는
  /// 없는" 소장품이 남고, 그 소장품은 고칠 수도 없다(확정본은 다시 만들기가
  /// 막힌다).
  Future<void> confirm() async {
    final answer = await OverlayService.choose(
      context,
      title: ViewerText.confirmTitle,
      message: ViewerText.confirmMessage,
      choices: const {
        'cancel': ViewerText.confirmCancel,
        'confirm': ViewerText.confirmOk,
      },
    );
    if (answer != 'confirm' || !mounted) return;

    final uploader = GoodsUploader(GoodsApiScope.of(context));
    final store = TicketStoreScope.read(context);
    setState(() => uploading = true);

    try {
      final goods = await uploader.upload(ticket);
      final confirmed = ticket.copyWith(
        confirmed: true,
        goodsId: goods.goodsId,
      );
      await store.save(confirmed);
      if (!mounted) return;
      setState(() {
        ticket = confirmed;
        uploading = false;
      });
      OverlayService.notify(context, ViewerText.confirmed);
    } catch (error) {
      if (!mounted) return;
      setState(() => uploading = false);
      OverlayService.notify(context, goodsFailureMessage(error));
    }
  }

  late final paletteFuture = PaletteExtractor.extract(
    widget.ticket.backgroundPath,
  );

  /// 개발용. 어떤 모델이 돌았고 무엇이 실패했는지 — 사용자가 볼 이유는 없고
  /// 우리가 결과를 따질 때만 필요해서 디버그 빌드에만 버튼이 있다.
  void showProcessingInfo(BuildContext context) => OverlayService.choose(
    context,
    title: ViewerText.processingInfo,
    message: [
      ...ticket.processingNotes,
      ticket.demoDepth
          ? '깊이 모델 미설치 또는 추론 실패: 데모 깊이 효과'
          : 'Depth Anything V2 Small 실제 추론',
      ticket.transition['firstFrameAnalyzed'] == true
          ? '사진과 데모 영상 첫 프레임 색상 분석 완료'
          : '첫 프레임 분석 불가: 기본 전환',
      '공식 영상 자리는 자체 제작 데모 영상으로 대체됨',
    ].join('\n\n'),
    choices: const {'close': '닫기'},
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<TicketPalette>(
    future: paletteFuture,
    builder: (context, snapshot) {
      final palette = snapshot.data ?? TicketPalette.fallback;
      // 설정이 바뀌면 여기가 다시 그려지고 카드가 센서를 놓거나 다시 잡는다.
      final tilt = TiltSettingScope.of(context);
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('메모리 소장품'),
          // 완성된 소장품은 고정이다. 깊이·조명·배치를 고칠 수 없다.
          leading: IconButton(
            tooltip: '소장품 목록으로',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          actions: [
            // 확정한 뒤에만 내보낸다. 아직 고칠 수 있는 것을 남에게 보이면,
            // 받은 사람이 본 소장품과 남는 소장품이 서로 달라진다.
            if (ticket.confirmed)
              IconButton(
                tooltip: ShareText.shareTooltip,
                onPressed: () => Navigator.push(
                  context,
                  stageRoute<void>(
                    StoryShareScreen(ticket: ticket, palette: palette),
                  ),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 22),
              ),
            IconButton(
              tooltip: ViewerText.guideTooltip,
              onPressed: () => showViewerGuide(context),
              icon: const Icon(Icons.help_outline_rounded, size: 22),
            ),
            IconButton(
              tooltip: tilt.enabled
                  ? ViewerText.tiltOnTooltip
                  : ViewerText.tiltOffTooltip,
              onPressed: tilt.toggle,
              icon: Icon(
                tilt.enabled
                    ? Icons.screen_rotation_rounded
                    : Icons.screen_lock_rotation_rounded,
                size: 22,
              ),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _AmbientBackdrop(path: ticket.backgroundPath, palette: palette),
            SafeArea(
              child: Column(
                children: [
                  if (created)
                    Reveal(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                        child: GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          radius: 999,
                          glow: palette.accent,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: TimoColors.accent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '소장품 제작과 로컬 저장이 완료됐어요!',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: TimoColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: ViewerConstants.cardAspect,
                          child: MemoryTicketCard(
                            ticket: ticket,
                            glow: palette.accent,
                            tiltBySensor: tilt.enabled,
                            wrap: (photo, drag, flip) => ImmersiveVideo(
                              photo: photo,
                              videoUrl: ticket.videoUrl,
                              transition: ticket.transition,
                              onDrag: drag,
                              onFlip: flip,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!ticket.confirmed)
                    Reveal(
                      index: 3,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 6),
                        child: _DraftBar(
                          onEdit: widget.onEdit == null || uploading
                              ? null
                              : () => widget.onEdit!(context),
                          onConfirm: uploading ? null : confirm,
                          uploading: uploading,
                        ),
                      ),
                    ),
                  // 조작법은 처음 열 때 안내로 보여주고, 처리 내역은 개발자만
                  // 본다. 카드 아래에는 확정 줄 말고 아무것도 두지 않는다.
                  if (kDebugMode)
                    TextButton(
                      onPressed: () => showProcessingInfo(context),
                      child: const Text(ViewerText.processingInfo),
                    )
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// 확정 전에만 뜨는 줄: 다시 만들기·확정하기와 상태 한 줄.
///
/// 제목·설명·아이콘을 갖춘 상자였는데, 안내가 카드보다 커져서 무엇을 보는
/// 화면인지 흐려졌다. 할 수 있는 일(버튼)을 먼저 놓고 상태는 아래 한 줄로 만다.
class _DraftBar extends StatelessWidget {
  const _DraftBar({
    required this.onEdit,
    required this.onConfirm,
    this.uploading = false,
  });
  final VoidCallback? onEdit;

  /// 올리는 중에는 null 이다. 같은 소장품을 두 번 올리지 않게 잠근다.
  final VoidCallback? onConfirm;
  final bool uploading;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          if (onEdit != null) ...[
            Expanded(
              child: TextButton(
                onPressed: onEdit,
                child: const Text(ViewerText.editLabel),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: GlowButton(
              label: uploading ? GoodsText.uploading : ViewerText.confirmLabel,
              onPressed: onConfirm,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: TimoColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            ViewerText.draftNote,
            style: TextStyle(fontSize: 11.5, color: TimoColors.textTertiary),
          ),
        ],
      ),
    ],
  );
}

/// 사진 자신의 색으로 만든 배경: 지배색 두 개로 물들인 오로라 덩어리, 아주
/// 작게 디코드한 사진 자체의 흐릿한 색면, 그리고 카드가 화면에서 가장 밝게
/// 남도록 덮는 어두운 그라데이션.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.path, required this.palette});
  final String path;
  final TicketPalette palette;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AnimatedSwitcher(
        duration: Motion.slow,
        child: AuroraBackground(
          key: ValueKey(palette.primary),
          intensity: 1.25,
          colors: [
            palette.primary,
            palette.secondary,
            Color.lerp(palette.accent, palette.primary, 0.4)!,
          ],
        ),
      ),
      Opacity(
        opacity: 0.3,
        child: LocalImage(
          path,
          fit: BoxFit.cover,
          cacheWidth: 24,
          filterQuality: FilterQuality.high,
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99070A12), Color(0x33070A12), Color(0xD9070A12)],
            stops: [0, 0.45, 1],
          ),
        ),
      ),
    ],
  );
}
