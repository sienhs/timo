import 'package:flutter/material.dart';

import '../../core/widgets/error_snack_bar.dart';
import 'constants.dart';
import 'widgets/quick_menu_panel.dart';

/// 빠른 메뉴를 열고, 고른 항목의 화면으로 보낸다. 화면이 아직 없으면 안내를 띄운다.
/// 하단 바를 다는 화면(셸·내 티켓)이 여럿이라 여기 한 곳에 둔다.
Future<void> openQuickMenu(BuildContext context) async {
  final selected = await showQuickMenu(context);
  if (selected == null || !context.mounted) return;

  final routeName = selected.routeName;
  if (routeName == null) {
    showInfoSnackBar(
      context,
      ShellStrings.notReady(selected.label),
      bottomMargin: snackBarGapAboveBar,
    );
    return;
  }
  Navigator.pushNamed(context, routeName);
}
