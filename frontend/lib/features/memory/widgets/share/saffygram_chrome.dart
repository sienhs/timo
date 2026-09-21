import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../theme/timo_colors.dart';
import '../ui/gradient_text.dart';

/// 싸피스타그램의 겉모습 조각들. 우리가 지은 이름과 우리가 그린 표식만 쓴다 —
/// 남의 로고를 흉내 내지 않는다.
class SaffygramMark extends StatelessWidget {
  const SaffygramMark({super.key, this.size = 15});
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size + 5,
        height: size + 5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular((size + 5) * 0.3),
          gradient: const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [TimoColors.gold, TimoColors.magenta, TimoColors.violet],
          ),
        ),
        child: Icon(
          Icons.camera_alt_rounded,
          size: size * 0.66,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 7),
      GradientText(
        ShareText.brand,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        gradient: const LinearGradient(
          colors: [TimoColors.gold, TimoColors.magenta, TimoColors.violet],
        ),
      ),
    ],
  );
}

/// 스토리 위쪽: 흘러가는 진행 막대와 올린 사람.
class StoryHeader extends StatelessWidget {
  const StoryHeader({super.key, required this.progress, required this.onClose});

  /// 0 → 1 로 차오르는 스토리 진행도.
  final Animation<double> progress;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AnimatedBuilder(
        animation: progress,
        builder: (_, _) => ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.value,
            minHeight: 2.5,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [TimoColors.accent, TimoColors.cyan],
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          const Text(
            ShareText.account,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            ShareText.justNow,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: ShareText.closeTooltip,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    ],
  );
}

/// 스토리 아래쪽의 답장 줄. 보여주기만 하고 아무것도 보내지 않는다.
class StoryReplyBar extends StatelessWidget {
  const StoryReplyBar({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white54),
          ),
          child: Text(
            ShareText.messageHint,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
      const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 26),
      const SizedBox(width: 14),
      const Icon(Icons.send_rounded, color: Colors.white, size: 24),
    ],
  );
}
