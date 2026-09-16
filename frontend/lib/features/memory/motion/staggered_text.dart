import 'package:flutter/material.dart';

import 'motion_tokens.dart';
import 'reveal.dart';

/// Headline that reveals word by word (GSAP-style stagger), one screen
/// reader label for the whole text. Reserved for headlines; body text
/// should stay a plain [Text].
class StaggeredText extends StatelessWidget {
  const StaggeredText(
    this.text, {
    super.key,
    required this.style,
    this.startIndex = 0,
    this.textAlign = TextAlign.start,
  });
  final String text;
  final TextStyle style;

  /// Stagger slot of the first word; following words count up from here.
  final int startIndex;
  final TextAlign textAlign;

  static List<List<String>> words(String text) => text
      .split('\n')
      .map((line) => line.split(' ').where((w) => w.isNotEmpty).toList())
      .toList();

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) {
      return Text(text, style: style, textAlign: textAlign);
    }
    var index = startIndex;
    final lines = words(text);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: textAlign == TextAlign.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Wrap(
              spacing: style.fontSize == null ? 6 : style.fontSize! * 0.26,
              children: [
                for (final word in line)
                  Reveal(
                    index: index++,
                    offset: Motion.revealOffset * 0.6,
                    child: Text(word, style: style),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
