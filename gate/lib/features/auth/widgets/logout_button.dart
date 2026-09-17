import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../state/auth_api_scope.dart';
import '../state/auth_session_scope.dart';

/// 스캔 화면 오른쪽 위의 로그아웃 버튼. 누르면 확인 팝업을 한 번 띄운다.
///
/// 팝업을 두는 이유: 바로 옆이 손전등 버튼이다. 관람객 줄 앞에서 잘못 눌러
/// 로그아웃되면 그 자리에서 아이디·비밀번호를 다시 쳐야 한다.
///
/// 확인하면 **기기 토큰을 먼저 지우고**([AuthSession.signOut]) 서버에 알린다
/// ([AuthApi.logout]). 순서가 이런 이유는 둘 중 기기 쪽이 중요하기 때문이다 —
/// 액세스 토큰은 서버가 끊지 못하는 JWT 라, 기기에 남아 있으면 남은 수명 동안
/// 그대로 통한다. 서버에 못 알려도(네트워크) 로그아웃은 된 것으로 친다.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AuthStrings.logout,
      icon: const Icon(Icons.logout),
      onPressed: () => _confirmAndLogout(context),
    );
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AuthStrings.logoutConfirmTitle),
        content: const Text(AuthStrings.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AuthStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AuthStrings.logout),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final session = AuthSessionScope.read(context);
    final api = AuthApiScope.of(context);

    final refreshToken = session.refreshToken;
    await session.signOut();
    if (refreshToken == null) return;
    try {
      await api.logout(refreshToken);
    } on ApiException {
      // 서버에 못 알렸다. 기기 토큰은 이미 지웠으니 로그아웃은 된 것이고, 서버
      // 세션은 만료로 스스로 정리된다.
    }
  }
}
