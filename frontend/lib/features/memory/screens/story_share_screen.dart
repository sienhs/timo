import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/memory_ticket.dart';
import '../motion/motion_tokens.dart';
import '../motion/reveal.dart';
import '../theme/timo_colors.dart';
import '../utils/palette_extractor.dart';
import '../widgets/share/saffygram_chrome.dart';
import '../widgets/share/story_stage.dart';
import '../widgets/ui/glass_panel.dart';
import '../widgets/ui/glow_button.dart';
import '../widgets/ui/overlay_service.dart';

/// 소장품을 싸피스타그램 스토리로 올리는 흉내.
///
/// 세 장면이다 — 올리기 전(미리보기와 선택지), 올리는 중(진행 막대), 올라간
/// 스토리. 진짜로 어디에도 보내지 않는다. 이 화면이 보여주는 것은 "스토리로
/// 공유하면 이렇게 보인다" 뿐이다.
///
/// 기울임을 켤지는 **올릴 때 고른다.** 앱의 기울임 설정은 내가 내 소장품을 볼
/// 때의 것이고, 이쪽은 스토리를 받는 사람에게 어떻게 보일지라 서로 다른 값이다.
class StoryShareScreen extends StatefulWidget {
  const StoryShareScreen({
    super.key,
    required this.ticket,
    required this.palette,
  });
  final MemoryTicket ticket;
  final TicketPalette palette;

  @override
  State<StoryShareScreen> createState() => _StoryShareScreenState();
}

enum _Phase { compose, uploading, posted }

class _StoryShareScreenState extends State<StoryShareScreen>
    with TickerProviderStateMixin {
  _Phase phase = _Phase.compose;
  bool tiltBySensor = true;

  // 올리지 않고 나가면 이 둘은 한 번도 안 쓰인다. 필드 초기화로 미뤄 두면
  // dispose 가 그제서야 만들면서 죽은 element 에서 Ticker 를 여니, 여기서
  // 미리 만든다([Reveal] 과 같은 이유).
  late final AnimationController upload;
  late final AnimationController story;

  @override
  void initState() {
    super.initState();
    upload =
        AnimationController(vsync: this, duration: ShareLayout.uploadDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _onUploaded();
          });
    story = AnimationController(
      vsync: this,
      duration: ShareLayout.storyDuration,
    );
  }

  @override
  void dispose() {
    upload.dispose();
    story.dispose();
    super.dispose();
  }

  void _post() {
    setState(() => phase = _Phase.uploading);
    // 동작 줄이기를 켠 사람에게는 막대를 채우지 않고 바로 끝낸 것으로 친다.
    if (Motion.reduced(context)) {
      upload.value = 1;
      return;
    }
    upload.forward(from: 0);
  }

  void _onUploaded() {
    if (!mounted) return;
    setState(() => phase = _Phase.posted);
    story.forward(from: 0);
    OverlayService.notify(context, ShareText.posted);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TimoColors.background,
    // 올라간 뒤에는 스토리가 화면 전체를 쓴다. 앱 막대가 남아 있으면 남의
    // 앱에서 보는 스토리처럼 보이지 않는다.
    appBar: phase == _Phase.posted
        ? null
        : AppBar(
            title: const Text(ShareText.title),
            leading: IconButton(
              tooltip: '돌아가기',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            ),
          ),
    body: switch (phase) {
      _Phase.compose => _Compose(
        ticket: widget.ticket,
        palette: widget.palette,
        tiltBySensor: tiltBySensor,
        onTiltChanged: (value) => setState(() => tiltBySensor = value),
        onPost: _post,
      ),
      _Phase.uploading => _Uploading(
        ticket: widget.ticket,
        palette: widget.palette,
        progress: upload,
      ),
      _Phase.posted => _Posted(
        ticket: widget.ticket,
        palette: widget.palette,
        tiltBySensor: tiltBySensor,
        progress: story,
        onClose: () => Navigator.pop(context),
      ),
    },
  );
}

/// 올리기 전: 스토리가 어떻게 보일지와, 기울임을 켤지 고르는 자리.
class _Compose extends StatelessWidget {
  const _Compose({
    required this.ticket,
    required this.palette,
    required this.tiltBySensor,
    required this.onTiltChanged,
    required this.onPost,
  });
  final MemoryTicket ticket;
  final TicketPalette palette;
  final bool tiltBySensor;
  final ValueChanged<bool> onTiltChanged;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: Reveal(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: AspectRatio(
                  aspectRatio: ShareLayout.storyAspect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    // 미리보기에서는 센서를 붙잡지 않는다. 기울임은 올라간
                    // 스토리에서 보여준다.
                    child: StoryStage(
                      ticket: ticket,
                      palette: palette,
                      tiltBySensor: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Reveal(
          index: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
            child: GlassPanel(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ShareText.tiltOption,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: TimoColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          ShareText.tiltOptionBody,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: TimoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch.adaptive(
                    value: tiltBySensor,
                    onChanged: onTiltChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
        Reveal(
          index: 2,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 2, 22, 18),
            child: GlowButton(
              label: ShareText.post,
              icon: Icons.add_circle_outline_rounded,
              onPressed: onPost,
            ),
          ),
        ),
      ],
    ),
  );
}

/// 올리는 중: 썸네일 아래로 막대가 찬다.
class _Uploading extends StatelessWidget {
  const _Uploading({
    required this.ticket,
    required this.palette,
    required this.progress,
  });
  final MemoryTicket ticket;
  final TicketPalette palette;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 128,
              child: AspectRatio(
                aspectRatio: ShareLayout.storyAspect,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: StoryStage(
                    ticket: ticket,
                    palette: palette,
                    tiltBySensor: false,
                    showMark: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SaffygramMark(),
            const SizedBox(height: 14),
            const Text(
              ShareText.uploading,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: TimoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: progress,
              builder: (_, _) => ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.value,
                  minHeight: 3,
                  backgroundColor: TimoColors.glass,
                  valueColor: const AlwaysStoppedAnimation(TimoColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 올라간 스토리. 여기서만 카드가 기울임에 반응한다.
class _Posted extends StatelessWidget {
  const _Posted({
    required this.ticket,
    required this.palette,
    required this.tiltBySensor,
    required this.progress,
    required this.onClose,
  });
  final MemoryTicket ticket;
  final TicketPalette palette;
  final bool tiltBySensor;
  final Animation<double> progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      StoryStage(ticket: ticket, palette: palette, tiltBySensor: tiltBySensor),
      SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
              child: StoryHeader(progress: progress, onClose: onClose),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 14),
              child: StoryReplyBar(),
            ),
          ],
        ),
      ),
    ],
  );
}
