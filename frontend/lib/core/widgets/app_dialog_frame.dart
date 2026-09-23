import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 앱 안 확인 팝업의 공통 틀. 흰 바탕, 둥근 모서리. 각 팝업은 안에 들어갈
/// 내용만 정한다. `Dialog` 에 배경을 맡기면 기본 그림자가 따라붙어 모서리가
/// 지저분해지므로 `Dialog` 는 비워 두고 안쪽 상자가 바탕과 모서리를 그린다.
class AppDialogFrame extends StatelessWidget {
  const AppDialogFrame({
    super.key,
    required this.child,
    this.padding = defaultPadding,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(20, 24, 20, 20);

  final Widget child;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
