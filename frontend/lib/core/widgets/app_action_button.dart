import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';

enum AppActionStyle { primary, secondary, destructive }

/// 긴 문구와 글자 확대에 맞춰 높이가 늘어나는 공통 행동 버튼.
class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppActionStyle.primary,
    this.isBusy = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppActionStyle variant;
  final bool isBusy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = compact
        ? AppMetrics.compactButtonMinHeight
        : AppMetrics.buttonMinHeight;
    final callback = isBusy ? null : onPressed;
    final content = Text(label, textAlign: TextAlign.center);
    final child = isBusy
        ? Semantics(
            liveRegion: true,
            label: '$label, 처리 중',
            child: ExcludeSemantics(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(opacity: 0, child: content),
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        : content;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return SizedBox(
      width: double.infinity,
      child: variant == AppActionStyle.secondary
          ? OutlinedButton(style: style, onPressed: callback, child: child)
          : FilledButton(
              style: variant == AppActionStyle.destructive
                  ? style.copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.disabled)
                            ? null
                            : scheme.error,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.disabled)
                            ? null
                            : scheme.onError,
                      ),
                    )
                  : style,
              onPressed: callback,
              child: child,
            ),
    );
  }
}
