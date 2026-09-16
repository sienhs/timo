import 'package:flutter/material.dart';

import '../../motion/ambient_motion.dart';

class OverlayService {
  /// Modal choice. While it is open the ambient backdrop calms down
  /// (slower aurora and smog) so the dialog reads as the focus.
  static Future<String?> choose(
    BuildContext context, {
    required String title,
    required String message,
    required Map<String, String> choices,
    bool destructive = false,
  }) async {
    AmbientMotion.instance.calm(true);
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: choices.entries
              .map(
                (e) => TextButton(
                  style: destructive && e.key == 'delete'
                      ? TextButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                        )
                      : null,
                  onPressed: () => Navigator.pop(context, e.key),
                  child: Text(e.value),
                ),
              )
              .toList(),
        ),
      );
    } finally {
      AmbientMotion.instance.calm(false);
    }
  }

  static void notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}
