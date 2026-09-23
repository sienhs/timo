import 'package:flutter/material.dart';

import '../../../../core/widgets/error_snack_bar.dart';
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

  /// 소장품 화면의 검정 토스트. 모양은 소장품 테마를 따르고, 줄 바꿈과 떠
  /// 있는 시간은 앱 공통 토스트와 같게 맞춘다.
  static void notify(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: toastDuration,
          content: Text(toastText(message), semanticsLabel: message),
        ),
      );
}
