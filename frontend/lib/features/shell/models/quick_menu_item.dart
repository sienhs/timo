import 'package:flutter/material.dart';

/// 빠른 메뉴 격자의 항목 하나.
///
/// [routeName] 이 null 이면 아직 화면이 없는 항목이다. 여기에 없는 라우트
/// 이름을 미리 [AppRoutes] 에 상수로 박아두지 않는다 — 열리지 않는 라우트가
/// 목록에 남으면 어느 화면이 실제로 있는지 코드만 봐서는 알 수 없다.
/// 화면이 생기면 그때 라우트를 등록하고 이 값만 채우면 된다.
@immutable
class QuickMenuItem {
  const QuickMenuItem({
    required this.icon,
    required this.label,
    this.routeName,
  });

  final IconData icon;
  final String label;
  final String? routeName;
}
