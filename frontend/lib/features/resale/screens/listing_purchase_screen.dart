import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../mypage/state/my_page_api_scope.dart';
import '../constants.dart';
import '../models/listing_detail.dart';
import '../models/purchased_trade.dart';
import '../state/resale_api_scope.dart';
import '../utils/idempotency_key.dart';
import '../widgets/listing_summary_card.dart';
import '../widgets/market_countdown.dart';
import '../widgets/market_hours_countdown.dart';
import '../widgets/purchase_transferring_view.dart';
import '../widgets/resale_app_bar.dart';
import '../widgets/resale_bottom_bar.dart';
import '../widgets/resale_summary_card.dart';

/// 양도 티켓 구매 확인 화면. 무엇을 얼마에 사는지 확인하고 결제한다.
///
/// 매물 번호만 받아 상세는 이 화면이 직접 조회한다. 목록에서 들고 온 값을
/// 그대로 쓰면 그 사이에 팔린 매물을 결제 화면까지 들고 가게 된다.
///
/// **남은 시간은 좌석 선점이 아니다.** 양도 매물에는 선점이 없어, 이 화면을
/// 열어 둔 사이에도 남이 사 갈 수 있다. 시간을 세는 이유는 화면이 든 가격이
/// 오래되면 결제가 거절되기 때문이다([ResaleMetrics.priceWindow]).
class ListingPurchaseScreen extends StatefulWidget {
  const ListingPurchaseScreen({
    super.key,
    required this.listingId,
    this.clock = DateTime.now,
  });

  final int listingId;

  /// 기기 시각을 읽는 함수. 가격 유효 시간과 상단 바의 마감 시간이 이 값을 본다.
  final DateTime Function() clock;

  @override
  State<ListingPurchaseScreen> createState() => _ListingPurchaseScreenState();
}

class _ListingPurchaseScreenState extends State<ListingPurchaseScreen> {
  Future<ListingDetail>? _listing;

  /// 받아 둔 매물. 하단 버튼이 [AsyncBoundary] 밖에 있어 여기에도 한 벌 든다.
  ListingDetail? _loaded;

  /// 지금 든 가격이 언제까지 유효한가. 상세를 받은 시각에서 잰다.
  DateTime? _expiresAt;
  bool _expired = false;

  /// 이번 구매 시도의 멱등키. 재시도는 같은 키로 보내야 결제가 두 번 일어나지
  /// 않는다. 상세를 다시 받으면(가격을 다시 확인한 것이므로) 새 시도가 된다.
  String _idempotencyKey = newIdempotencyKey();

  /// 결제 요청을 보내고 응답을 기다리는 중. 그동안 버튼을 잠근다.
  bool _purchasing = false;

  /// 지갑 잔액. 매물가보다 적으면 결제 버튼을 잠근다.
  ///
  /// 못 읽었으면 null 이고, 그때는 잠그지 않는다. 이 확인은 안내일 뿐이고
  /// 판정은 서버가 한다 — 지갑을 못 읽었다는 이유로 앱이 결제를 막으면,
  /// 서버가 받아 줄 거래를 앱이 대신 거절하는 꼴이 된다.
  int? _balance;

  /// 잔액을 읽는 일. 한 번만 걸도록 들고 있는다([_listing] 과 같은 이유다).
  Future<void>? _balanceLoad;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listing ??= _load();
    _balanceLoad ??= _loadBalance();
  }

  /// 지갑 잔액을 미리 읽어 둔다.
  ///
  /// 매물 상세와 달리 [AsyncBoundary] 에 걸지 않는다. 잔액을 못 읽은 것은
  /// 매물을 못 읽은 것과 달라서, 화면 전체를 오류로 덮을 일이 아니다. 실패는
  /// 삼키고 잔액을 모르는 채로 둔다([_balance]).
  Future<void> _loadBalance() async {
    final api = MyPageApiScope.of(context);
    try {
      final wallet = await api.fetchWallet();
      if (mounted) setState(() => _balance = wallet.balance);
    } on ApiException {
      // 잔액을 모르는 채로 둔다. 결제 가능 여부는 서버가 판정한다.
    }
  }

  Future<ListingDetail> _load() async {
    final listing = await ResaleApiScope.of(
      context,
    ).fetchListing(widget.listingId);
    // Future 안이라 빌드 중이 아니다. 하단 버튼이 읽을 수 있게 기억해 둔다.
    if (mounted) {
      setState(() {
        _loaded = listing;
        _expiresAt = widget.clock().add(ResaleMetrics.priceWindow);
      });
    }
    return listing;
  }

  void _reload() {
    setState(() {
      _loaded = null;
      _expired = false;
      _expiresAt = null;
      _idempotencyKey = newIdempotencyKey();
      _listing = _load();
      // 다른 화면에서 충전하고 돌아왔을 수 있다. 잔액도 다시 읽는다.
      _balance = null;
      _balanceLoad = _loadBalance();
    });
  }

  Future<void> _purchase() async {
    final listing = _loaded;
    if (listing == null || _purchasing) return;

    setState(() => _purchasing = true);
    final api = ResaleApiScope.of(context);
    try {
      final trade = await api.purchase(
        listingId: listing.listingId,
        expectedPrice: listing.price,
        idempotencyKey: _idempotencyKey,
      );
      if (!mounted) return;
      // 완료 화면으로 갈아탄다. 결제가 끝난 뒤 뒤로가기로 이 화면에 돌아오면
      // 이미 팔린 매물을 다시 사려는 꼴이 된다.
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.resalePurchaseComplete,
        arguments: PurchaseResult(
          trade: trade,
          posterImageUrl: listing.posterImageUrl,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // 연출을 걷고 버튼을 되살린다. 이걸 빼면 실패한 자리에서 연출이 그대로
      // 남고, 걷어 낸다 해도 버튼이 잠긴 채라 나갔다 들어와야 다시 살 수 있다.
      setState(() => _purchasing = false);
      showErrorSnackBar(context, e.message);
      // 거절의 이유가 매물 쪽에 있을 수 있다(그새 팔림·가격 불일치·마켓 마감).
      // 다시 받아 와 화면이 지금 상태를 말하게 한다.
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 요청이 나가 있는 동안에는 화면 전체가 연출이다. 남은 시간을 세는 상단
    // 바도, 누를 것이 없어진 하단 버튼도 그동안은 할 말이 없다.
    if (_purchasing) {
      return const PopScope(
        // 보낸 요청을 무를 방법이 없다. 뒤로 나가면 결제가 끝났는지 모르는 채로
        // 목록에 서게 된다.
        canPop: false,
        child: Scaffold(
          // 자산의 배경이 흰색이다. 마켓의 연회색 위에 올리면 흰 사각형이 떠
          // 보인다(`PurchaseTransferringView` 주석).
          backgroundColor: Colors.white,
          body: SafeArea(child: PurchaseTransferringView()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: resalePageBackground,
      appBar: ResaleAppBar(
        title: ResaleStrings.purchaseTitle,
        trailing: MarketClosingCountdown(clock: widget.clock),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: AsyncBoundary<ListingDetail>(
                future: _listing!,
                onRetry: _reload,
                builder: (context, listing) => SingleChildScrollView(
                  padding: const EdgeInsets.all(
                    ResaleMetrics.horizontalPadding,
                  ),
                  child: ListingSummaryCard(listing: listing),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final listing = _loaded;
    final expiresAt = _expiresAt;

    // 아직 못 받았거나 실패했다. 누를 것이 없으니 잠근 버튼만 둔다.
    if (listing == null || expiresAt == null) {
      return const ResaleBottomBar(
        child: ResaleActionButton(
          label: ResaleStrings.purchaseAction,
          onPressed: null,
        ),
      );
    }

    // 살 수 없는 매물. 이유를 적고 버튼을 잠근다.
    if (!listing.canPurchase) {
      return ResaleBottomBar(
        notice: listing.mine
            ? ResaleStrings.ownListing
            : ResaleStrings.listingClosed,
        child: const ResaleActionButton(
          label: ResaleStrings.purchaseAction,
          onPressed: null,
        ),
      );
    }

    // 잔액이 모자란다. 이대로 결제하면 온체인에서 되돌려지는데, 그때 서버가
    // 주는 문구는 "잠시 후 다시 시도해 주세요" 라(`TRANSFER_FAILED`) 충전하러
    // 가야 하는 사람을 재시도로 보낸다. 앱이 먼저 잠그고 이유를 적는다.
    //
    // 가격 만료보다 먼저 보는 이유는, 모자란 잔액은 다시 불러와도 그대로라서다.
    final balance = _balance;
    if (balance != null && balance < listing.price) {
      return const ResaleBottomBar(
        notice: ResaleStrings.insufficientBalance,
        noticeColor: AppColors.error,
        child: ResaleActionButton(
          label: ResaleStrings.purchaseAction,
          onPressed: null,
        ),
      );
    }

    // 가격을 확인한 지 오래됐다. 결제 대신 다시 불러오기를 둔다.
    if (_expired) {
      return ResaleBottomBar(
        notice: ResaleStrings.priceExpired,
        noticeColor: AppColors.textSecondary,
        child: ResaleActionButton(
          label: ResaleStrings.priceExpiredAction,
          onPressed: _reload,
        ),
      );
    }

    return ResaleBottomBar(
      notice: ResaleStrings.purchaseWarning,
      child: MarketCountdown(
        until: expiresAt,
        clock: widget.clock,
        onElapsed: () => setState(() => _expired = true),
        semanticsLabel: ResaleStrings.purchaseActionWithRemaining,
        builder: (context, remaining) => ResaleActionButton(
          label: ResaleStrings.purchaseActionWithRemaining(remaining),
          onPressed: _purchasing ? null : _purchase,
        ),
      ),
    );
  }
}
