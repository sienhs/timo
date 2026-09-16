import 'package:flutter/material.dart';

import '../../motion/ambient_motion.dart';
import '../../motion/motion_tokens.dart';
import '../../motion/press_scale.dart';
import '../../theme/timo_colors.dart';

/// Photo / effect tile: the picture fills the card; selection draws a green
/// frame and pops a check badge. [label] is for accessibility only, matching
/// the mock-ups where tiles carry no caption.
class SelectionTile extends StatefulWidget {
  const SelectionTile({
    super.key,
    required this.child,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });
  final Widget child;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Grey "+" style tile (gallery picker).
  final bool muted;
  @override
  State<SelectionTile> createState() => _SelectionTileState();
}

class _SelectionTileState extends State<SelectionTile> {
  bool pressed = false;
  bool get selected => widget.selected;

  void focusHere(TapDownDetails details) {
    final size = MediaQuery.sizeOf(context);
    AmbientMotion.instance.focusOn(
      Offset(
        details.globalPosition.dx / size.width,
        details.globalPosition.dy / size.height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: widget.label,
    child: PressScale(
      onTap: widget.onTap,
      onTapDown: focusHere,
      lift: 2,
      onPressChanged: (down) => setState(() => pressed = down),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.standard,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: widget.muted
              ? TimoColors.placeholder
              : const Color(0xFF0B0F1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? TimoColors.brandMid : Colors.transparent,
            width: selected ? 2.5 : 0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: TimoColors.brandMid.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedScale(
              scale: pressed ? 1.04 : 1,
              duration: Motion.fast,
              curve: Motion.standard,
              child: widget.child,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: Motion.base,
                curve: Motion.overshoot,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: TimoColors.brandMid,
                    boxShadow: [
                      BoxShadow(color: Color(0x553A9A63), blurRadius: 10),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
