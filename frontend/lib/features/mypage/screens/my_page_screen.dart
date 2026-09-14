import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_api_scope.dart';
import '../../auth/state/auth_session.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import '../state/my_page_api_scope.dart';
import '../widgets/mushroom_balance_card.dart';
import '../widgets/my_page_top_bar.dart';
import '../widgets/transaction_history_card.dart';

/// 마이페이지 홈. `MainShellScreen` 의 두 번째 탭 본문이다.
///
/// Scaffold 를 두지 않는다 — 셸이 이미 Scaffold 와 하단 바를 들고 있다.
///
/// 로그인 여부로 본문이 갈린다. 로그인 상태면 인사말·잔액·사용 내역을
/// 서버에서 받아 그리고([_MemberView]), 아니면 로그인 입구만 보여 준다
/// ([_GuestView]). 세션이 바뀌면 이 화면도 다시 그려져 본문이 바뀐다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key, this.onBackPressed});

  /// 뒤로가기. 셸이 홈 탭으로 돌리는 콜백을 넘긴다. 없으면(단독 실행) 이전
  /// 라우트로 돌아간다.
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    // 스코프 없이 셸만 띄우는 테스트에서는 null 이라 로그아웃 상태로 본다.
    final session = AuthSessionScope.maybeOf(context);
    final isLoggedIn = session?.isLoggedIn ?? false;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          MyPageTopBar(
            onBackPressed: onBackPressed ?? () => Navigator.maybePop(context),
            onNotificationsPressed: () =>
                _notifyNotReady(context, MyPageStrings.notifications),
          ),
          Expanded(
            child: isLoggedIn
                // 다른 회원으로 다시 로그인하면 새로 받아 오도록 키를 건다.
                ? _MemberView(
                    key: ValueKey(session!.memberId),
                    session: session,
                  )
                : const _GuestView(),
          ),
        ],
      ),
    );
  }
}

/// 로그인한 회원의 마이페이지. 인사말과 지갑을 각각 받아 온다.
///
/// 둘을 따로 드는 이유: 회원 정보는 실제 서버, 지갑은 아직 목업이라 실패
/// 양상이 다르다. 한쪽이 실패해도 다른 쪽은 그대로 보인다.
class _MemberView extends StatefulWidget {
  const _MemberView({super.key, required this.session});

  final AuthSession session;

  @override
  State<_MemberView> createState() => _MemberViewState();
}

class _MemberViewState extends State<_MemberView> {
  late Future<MemberProfile> _profile;
  late Future<WalletSummary> _wallet;

  @override
  void initState() {
    super.initState();
    final api = MyPageApiScope.of(context);
    _profile = api.fetchProfile();
    _wallet = api.fetchWallet();
  }

  void _reloadProfile() {
    setState(() {
      _profile = MyPageApiScope.of(context).fetchProfile();
    });
  }

  void _reloadWallet() {
    setState(() {
      _wallet = MyPageApiScope.of(context).fetchWallet();
    });
  }

  /// 로그아웃. 기기 토큰을 먼저 지우고, 서버에는 알려만 준다.
  ///
  /// 순서가 중요하다. 세션을 비우면 리프레시 토큰이 사라지므로 서버에 보낼 값을
  /// 먼저 꺼내 둔다. 세션을 비우는 순간 화면이 로그인 입구로 바뀌어 사용자는
  /// 서버 응답을 기다리지 않는다.
  ///
  /// 서버에 못 알려도(네트워크 끊김) 로그아웃은 된 것으로 친다. 기기 토큰은 이미
  /// 지웠고, 서버 쪽 세션은 30일 뒤 저절로 만료된다. 여기서 실패를 알려 봐야
  /// 사용자가 할 수 있는 일이 없다.
  ///
  /// 세션([AuthSession.signOut]) 안에 서버 호출을 넣지 않은 이유: 그 메서드는
  /// 401 을 받은 인터셉터도 부르는데, 그때는 토큰이 이미 안 통하는 상태라 서버에
  /// 알릴 게 없다. 로그아웃 진입점이 늘면 이 세 단계를 헬퍼로 뺀다.
  Future<void> _logout() async {
    // await 앞에서 context 를 다 쓴다. 뒤에서 쓰면 화면이 사라진 뒤일 수 있다.
    final api = AuthApiScope.of(context);
    final session = widget.session;
    final refreshToken = session.refreshToken;

    await session.signOut();

    if (refreshToken == null) return;
    try {
      await api.logout(refreshToken);
    } on ApiException {
      // 서버에 못 알린 것뿐이다. 위 설명대로 무시한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MyPageMetrics.horizontalPadding,
        MyPageMetrics.greetingTopGap,
        MyPageMetrics.horizontalPadding,
        MyPageMetrics.bottomGap,
      ),
      children: [
        AsyncBoundary<MemberProfile>(
          future: _profile,
          onRetry: _reloadProfile,
          loading: const _GreetingPlaceholder(),
          builder: (context, profile) => _Greeting(nickname: profile.nickname),
        ),
        const SizedBox(height: MyPageMetrics.greetingBottomGap),
        AsyncBoundary<WalletSummary>(
          future: _wallet,
          onRetry: _reloadWallet,
          loading: const _WalletPlaceholder(),
          builder: (context, wallet) => Column(
            children: [
              MushroomBalanceCard(
                balance: wallet.balance,
                onChargePressed: () =>
                    _notifyNotReady(context, MyPageStrings.charge),
              ),
              const SizedBox(height: MyPageMetrics.cardGap),
              TransactionHistoryCard(
                transactions: wallet.transactions,
                onSeeAllPressed: () =>
                    _notifyNotReady(context, MyPageStrings.seeAllHistory),
              ),
            ],
          ),
        ),
        const SizedBox(height: MyPageMetrics.logoutTopGap),
        // 화면의 primary 는 충전하기 하나다. 로그아웃은 보조 스타일로 둔다.
        Center(
          child: OutlinedButton(
            onPressed: _logout,
            child: const Text(AuthStrings.logout),
          ),
        ),
      ],
    );
  }
}

/// `{닉네임} 님 환영해요!`. 닉네임만 굵다.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: nickname, style: textTheme.headlineSmall),
          TextSpan(
            text: MyPageStrings.greetingSuffix,
            style: textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// 인사말을 기다리는 동안 자리만 지킨다. 한 줄 높이라 스피너를 돌릴 만한
/// 자리가 아니다 — 응답이 오면 글자로 바뀐다.
class _GreetingPlaceholder extends StatelessWidget {
  const _GreetingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    return SizedBox(height: (style?.fontSize ?? 0) * (style?.height ?? 1));
  }
}

class _WalletPlaceholder extends StatelessWidget {
  const _WalletPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: MyPageMetrics.loadingCardHeight,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 로그인 안 한 상태. 안내 한 줄과 로그인 입구만 있다.
class _GuestView extends StatelessWidget {
  const _GuestView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MyPageMetrics.horizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              MyPageStrings.loginPrompt,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: MyPageMetrics.greetingBottomGap),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              child: const Text(AuthStrings.login),
            ),
          ],
        ),
      ),
    );
  }
}

void _notifyNotReady(BuildContext context, String label) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(MyPageStrings.notReady(label))));
}
