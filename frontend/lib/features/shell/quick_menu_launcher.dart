import 'package:flutter/material.dart';

import 'constants.dart';
import 'widgets/quick_menu_panel.dart';

/// 빠른 메뉴를 열고, 고른 항목의 화면으로 보낸다.
///
/// 셸 안에 있던 것을 여기로 뺐다. 하단 바를 다는 화면이 셸 말고도 생기면서
/// (내 티켓) 같은 로직이 둘이 됐다. 패널을 여는 법과 "화면이 아직 없으면
/// 안내를 띄운다" 는 규칙이 두 곳에 갈라져 있으면, 화면이 하나 생길 때마다
/// 양쪽을 같이 고쳐야 한다.
Future<void> openQuickMenu(BuildContext context) async {
  final selected = await showQuickMenu(context);
  if (selected == null || !context.mounted) return;

  final routeName = selected.routeName;
  if (routeName == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ShellStrings.notReady(selected.label))),
    );
    return;
  }
  Navigator.pushNamed(context, routeName);
}
