import 'package:flutter/material.dart';

/// 빠른 메뉴 격자의 항목 하나.
/// [routeName] 이 null 이면 아직 화면이 없는 항목이다. 열리지 않는 라우트 이름을
/// 미리 `AppRoutes` 에 박아 두지 않고, 화면이 생기면 그때 등록하고 이 값을 채운다.
@immutable
class QuickMenuItem {
  const QuickMenuItem({
    required this.icon,
    required this.label,
    this.routeName,
    this.customIcon,
  });

  final IconData icon;
  final String label;
  final String? routeName;
  final Widget? customIcon;
}
