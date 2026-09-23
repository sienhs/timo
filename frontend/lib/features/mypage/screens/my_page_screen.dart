import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_api_scope.dart';
import '../../auth/state/auth_session.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../notification/push_notification_scope.dart';
import '../constants.dart';
import '../models/member_profile.dart';
import '../models/wallet_summary.dart';
import '../state/my_page_api_scope.dart';
import '../widgets/mushroom_balance_card.dart';
import '../widgets/my_page_top_bar_host.dart';
import '../widgets/transaction_history_card.dart';

/// 마이페이지 홈. `MainShellScreen` 의 두 번째 탭 본문이라 Scaffold 를 두지
/// 않는다. 로그인 상태면 인사말·잔액·사용 내역을 서버에서 받아 그리고
/// ([_MemberView]), 아니면 로그인 입구만 보여 준다([_GuestView]).
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
          MyPageTopBarHost(
            onBackPressed: onBackPressed ?? () => Navigator.maybePop(context),
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

/// 로그인한 회원의 마이페이지. 인사말과 지갑을 각각 받아 와 한쪽이 실패해도
/// 다른 쪽은 그대로 보인다.
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

  /// 충전 화면으로 보내고, 충전하고 돌아왔으면 지갑을 다시 받아 온다. 충전과 함께
  /// 사용 내역도 늘어나므로 새 잔액만 넘겨받지 않고 지갑 전체를 다시 받는다.
  Future<void> _openCharge() async {
    final charged = await Navigator.pushNamed(context, AppRoutes.coinCharge);
    if (charged == true && mounted) _reloadWallet();
  }

  /// 로그아웃. 푸시 토큰 해제 → 세션 비우기 → 서버 통보 순서다. 푸시 해제
  /// (`PushDeviceRegistrar.unregisterDevice`)는 인증 헤더가 필요해 세션을 비우기
  /// 전에 해야 하고, 리프레시 토큰은 세션이 비면 사라지므로 먼저 꺼내 둔다. 서버에
  /// 못 알려도 로그아웃은 된 것으로 친다 — 서버 세션은 30일 뒤 저절로 만료된다.
  Future<void> _logout() async {
    // await 앞에서 context 를 다 쓴다. 뒤에서 쓰면 화면이 사라진 뒤일 수 있다.
    final api = AuthApiScope.of(context);
    // 스코프 없이 화면만 띄우는 테스트에서는 null 이라 해제를 건너뛴다.
    final pushRegistrar = PushNotificationScope.maybeOf(context);
    final session = widget.session;
    final refreshToken = session.refreshToken;

    await pushRegistrar?.unregisterDevice();
    await session.signOut();

    if (refreshToken == null) return;
    try {
      await api.logout(refreshToken);
    } on ApiException {
      // 서버에 못 알린 것뿐이다. 위 설명대로 무시한다.
    }
  }

  /// 페이지 자체는 굴리지 않는다. 인사말·잔액·로그아웃은 제 높이를 다 차지하고,
  /// 남는 자리를 코인 내역 카드가 받아 그 안에서 굴린다. 내역이 아무리 쌓여도
  /// 로그아웃을 보려고 페이지를 내릴 일은 없다.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MyPageMetrics.horizontalPadding,
        MyPageMetrics.greetingTopGap,
        MyPageMetrics.horizontalPadding,
        MyPageMetrics.bottomGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AsyncBoundary<MemberProfile>(
            future: _profile,
            onRetry: _reloadProfile,
            loading: const _GreetingPlaceholder(),
            builder: (context, profile) =>
                _Greeting(nickname: profile.nickname),
          ),
          const SizedBox(height: MyPageMetrics.greetingBottomGap),
          // 남은 높이까지만 차지한다(loose). 내역이 적으면 그만큼만 높아진다.
          Flexible(
            child: AsyncBoundary<WalletSummary>(
              future: _wallet,
              onRetry: _reloadWallet,
              loading: const _WalletPlaceholder(),
              builder: (context, wallet) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MushroomBalanceCard(
                    balance: wallet.balance,
                    onChargePressed: _openCharge,
                  ),
                  const SizedBox(height: MyPageMetrics.cardGap),
                  Flexible(
                    child: TransactionHistoryCard(
                      transactions: wallet.transactions,
                    ),
                  ),
                ],
              ),
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
      ),
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
