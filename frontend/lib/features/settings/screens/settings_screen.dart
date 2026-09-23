import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// 환경 설정. 빠른 메뉴로 들어오며 계정 · 알림 · 앱 정보 세 묶음이다.
/// 화면이 있는 항목은 그 화면으로 보내고, 아직 없는 항목은 준비 중 안내를 띄운다.
/// 로그인 안 한 상태로도 열리며 그때는 계정 묶음 자리에 로그인 입구만 보여 준다.
/// 로그아웃은 마이페이지에 이미 있어 여기 두지 않는다.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 푸시 알림 스위치. 화면 안에서만 켜지고 꺼진다 — 기기 토큰 등록을 끄고
  /// 켜는 일은 아직 붙이지 않았다. 저장하지 않으므로 화면을 나가면 켜진
  /// 상태로 돌아온다.
  bool _pushEnabled = true;

  void _togglePush([bool? value]) {
    setState(() => _pushEnabled = value ?? !_pushEnabled);
  }

  void _notReady(String label) {
    showInfoSnackBar(context, SettingsStrings.notReady(label));
  }

  /// Flutter 가 기본으로 제공하는 라이선스 화면. 앱이 쓰는 패키지의 라이선스를
  /// 스스로 모아 보여 준다.
  void _openLicenses() {
    showLicensePage(
      context: context,
      applicationName: SettingsStrings.appName,
      applicationVersion: SettingsStrings.appVersion,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 스코프 없이 화면만 띄우는 테스트에서는 null 이라 로그아웃 상태로 본다.
    final isLoggedIn = AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text(SettingsStrings.title)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: SettingsMetrics.horizontalPadding,
            vertical: SettingsMetrics.verticalPadding,
          ),
          children: [
            SettingsSection(
              title: SettingsStrings.accountSection,
              children: isLoggedIn
                  ? [
                      SettingsTile(
                        icon: Icons.person_outline,
                        label: SettingsStrings.editProfile,
                        onTap: () => _notReady(SettingsStrings.editProfile),
                      ),
                      SettingsTile(
                        icon: Icons.lock_outline,
                        label: SettingsStrings.changePassword,
                        onTap: () => _notReady(SettingsStrings.changePassword),
                      ),
                      SettingsTile(
                        icon: Icons.person_remove_outlined,
                        label: SettingsStrings.deleteAccount,
                        onTap: () => _notReady(SettingsStrings.deleteAccount),
                      ),
                    ]
                  : const [_GuestPrompt()],
            ),
            const SizedBox(height: SettingsMetrics.sectionGap),
            SettingsSection(
              title: SettingsStrings.notificationSection,
              children: [
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  label: SettingsStrings.pushToggle,
                  trailing: Switch(value: _pushEnabled, onChanged: _togglePush),
                  onTap: _togglePush,
                ),
                SettingsTile(
                  icon: Icons.inbox_outlined,
                  label: SettingsStrings.inbox,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                ),
              ],
            ),
            const SizedBox(height: SettingsMetrics.sectionGap),
            SettingsSection(
              title: SettingsStrings.infoSection,
              children: [
                SettingsTile(
                  icon: Icons.info_outline,
                  label: SettingsStrings.version,
                  trailing: Text(
                    SettingsStrings.appVersion,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  label: SettingsStrings.terms,
                  onTap: () => _notReady(SettingsStrings.terms),
                ),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  label: SettingsStrings.privacy,
                  onTap: () => _notReady(SettingsStrings.privacy),
                ),
                SettingsTile(
                  icon: Icons.code,
                  label: SettingsStrings.licenses,
                  onTap: _openLicenses,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 안 한 상태의 계정 묶음. 안내 한 줄과 로그인 입구만 있다.
class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SettingsMetrics.guestPadding),
      child: Column(
        children: [
          Text(
            SettingsStrings.loginPrompt,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: SettingsMetrics.guestGap),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            child: const Text(AuthStrings.login),
          ),
        ],
      ),
    );
  }
}
