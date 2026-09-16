import 'package:flutter/material.dart';

import '../../motion/motion_tokens.dart';
import '../../theme/timo_colors.dart';
import '../../constants.dart';

enum CollectionFilter { mine, all }

/// "내가 가진 티켓만 보기 | 모두 보기" — right-aligned text toggle.
class CollectionFilterBar extends StatelessWidget {
  const CollectionFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final CollectionFilter value;
  final ValueChanged<CollectionFilter> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      _FilterLabel(
        text: CollectionText.filterMine,
        active: value == CollectionFilter.mine,
        onTap: () => onChanged(CollectionFilter.mine),
      ),
      Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: TimoColors.line,
      ),
      _FilterLabel(
        text: CollectionText.filterAll,
        active: value == CollectionFilter.all,
        onTap: () => onChanged(CollectionFilter.all),
      ),
    ],
  );
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel({
    required this.text,
    required this.active,
    required this.onTap,
  });
  final String text;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: Motion.base,
          curve: Motion.standard,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? TimoColors.brandMid : TimoColors.inkTertiary,
            letterSpacing: -0.2,
          ),
          child: Text(text),
        ),
      ),
    ),
  );
}
