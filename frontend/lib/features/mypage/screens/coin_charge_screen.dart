import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/charge_amount.dart';
import '../models/wallet_summary.dart';
import '../state/my_page_api_scope.dart';
import '../widgets/charge_amount_card.dart';
import '../widgets/mushroom_balance_card.dart';
import '../widgets/my_page_top_bar_host.dart';

/// 버섯 충전 화면. 마이페이지의 충전하기와 빠른 메뉴의 코인 충전에서 들어온다.
/// 충전에 성공하면 결과로 true 를 넘기며 닫히고, 지갑을 다시 그리는 건 부른 쪽
/// 몫이다. 잔액 조회가 실패해도 충전 카드는 그대로 보인다.
class CoinChargeScreen extends StatefulWidget {
  const CoinChargeScreen({super.key});

  @override
  State<CoinChargeScreen> createState() => _CoinChargeScreenState();
}

class _CoinChargeScreenState extends State<CoinChargeScreen> {
  final _controller = TextEditingController();

  /// 잔액 조회. 로그인 상태가 아니면 보내지 않는다.
  Future<WalletSummary>? _wallet;

  /// 받아 둔 잔액. 요약 줄이 [AsyncBoundary] 밖에 있어 여기에도 한 벌 든다.
  /// 아직 못 받았거나 실패했으면 null 이다.
  int? _balance;

  /// 충전 요청을 보내고 응답을 기다리는 중. 그동안 버튼을 잠가 두 번 눌러
  /// 두 번 충전되지 않게 한다.
  bool _charging = false;

  ChargeAmount get _amount => ChargeAmount.parse(_controller.text);

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void initState() {
    super.initState();
    // 금액이 바뀌면 고른 칸·요약·버튼이 함께 바뀐다. 상태는 컨트롤러 하나뿐이다.
    _controller.addListener(_onAmountChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인한 채로 들어왔거나, 이 화면에서 로그인하고 돌아왔을 때 잔액을
    // 받아 온다. 로그아웃되면(401) 들고 있던 잔액을 버린다.
    if (_isLoggedIn) {
      _wallet ??= _loadWallet();
    } else {
      _wallet = null;
      _balance = null;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onAmountChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onAmountChanged() => setState(() {});

  Future<WalletSummary> _loadWallet() async {
    final wallet = await MyPageApiScope.of(context).fetchWallet();
    // Future 안이라 빌드 중이 아니다. 요약 줄이 읽을 수 있게 기억해 둔다.
    if (mounted) setState(() => _balance = wallet.balance);
    return wallet;
  }

  void _reloadWallet() {
    setState(() {
      _balance = null;
      _wallet = _loadWallet();
    });
  }

  /// 금액 칸을 누르면 입력칸에 그 금액을 써 준다. 화면에 금액이 한 군데(입력칸)
  /// 에만 있으므로 고른 칸 표시와 요약이 저절로 따라온다.
  void _selectPreset(int value) {
    // 직접 친 것처럼 보이도록 쉼표를 넣어 둔다. 포매터는 사람이 칠 때만 돈다.
    final text = formatThousands(value);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _charge() async {
    final amount = _amount;
    if (_charging || !amount.canSubmit) return;

    setState(() => _charging = true);
    final api = MyPageApiScope.of(context);
    try {
      await api.charge(amount.value);
      if (!mounted) return;
      // 스낵바를 먼저 띄운다. ScaffoldMessenger 는 라우트보다 위에 있어 이 화면이
      // 닫혀도 남는다. 폭은 글자에 맞춰 마이페이지 카드처럼 보이지 않게 한다.
      showSuccessSnackBar(
        context,
        MyPageStrings.chargeSucceeded(formatThousands(amount.value)),
        fitContent: true,
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 입력값은 그대로 둔다. 다시 누르면 같은 금액으로 다시 보낸다.
      showErrorSnackBar(context, e.message);
      setState(() => _charging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: Column(
          children: [
            ColoredBox(
              color: AppColors.surface,
              child: MyPageTopBarHost(
                title: MyPageStrings.chargeTitle,
                onBackPressed: () => Navigator.maybePop(context),
              ),
            ),
            const Divider(),
            Expanded(child: _isLoggedIn ? _buildForm() : const _GuestView()),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final amount = _amount;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              MyPageMetrics.horizontalPadding,
              MyPageMetrics.chargeTopGap,
              MyPageMetrics.horizontalPadding,
              MyPageMetrics.chargeTopGap,
            ),
            children: [
              AsyncBoundary<WalletSummary>(
                future: _wallet!,
                onRetry: _reloadWallet,
                loading: const _BalancePlaceholder(),
                builder: (context, wallet) =>
                    MushroomBalanceCard(balance: wallet.balance),
              ),
              const SizedBox(height: MyPageMetrics.cardGap),
              ChargeAmountCard(
                controller: _controller,
                amount: amount,
                balance: _balance,
                onPresetSelected: _selectPreset,
              ),
            ],
          ),
        ),
        ColoredBox(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(MyPageMetrics.chargeSubmitPadding),
            child: FilledButton(
              onPressed: amount.canSubmit && !_charging ? _charge : null,
              child: const Text(MyPageStrings.chargeSubmit),
            ),
          ),
        ),
      ],
    );
  }
}

/// 잔액을 기다리는 동안 카드 자리를 지킨다. 마이페이지와 같은 모양이다.
class _BalancePlaceholder extends StatelessWidget {
  const _BalancePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: MyPageMetrics.loadingCardHeight,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 로그인 안 한 상태. 빠른 메뉴는 로그인 여부를 묻지 않아 여기로 들어올 수
/// 있다. 충전할 지갑이 없으므로 로그인 입구만 보여 준다.
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
              MyPageStrings.chargeLoginPrompt,
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
