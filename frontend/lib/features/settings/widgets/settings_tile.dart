import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../constants.dart';

/// 환경 설정 항목 한 줄. 왼쪽 아이콘, 이름, 오른쪽 꼬리.
///
/// 꼬리([trailing])를 넘기지 않으면 누를 수 있는 줄에는 화살표가 붙고, 누를 수
/// 없는 줄(버전)에는 아무것도 붙지 않는다. 스위치나 값 글자를 달 때만 넘긴다.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SettingsMetrics.tileHorizontalPadding,
      ),
      leading: Icon(
        icon,
        size: SettingsMetrics.tileIconSize,
        color: AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
      ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : const Icon(
                  Icons.chevron_right,
                  size: SettingsMetrics.chevronSize,
                  color: AppColors.textDisabled,
                )),
      onTap: onTap,
    );
  }
}
