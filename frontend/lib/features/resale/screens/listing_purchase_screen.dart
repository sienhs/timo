import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/listing_detail.dart';
import '../models/market_hours.dart';
import '../models/purchased_trade.dart';
import '../state/resale_api_scope.dart';
import '../utils/idempotency_key.dart';
import '../widgets/listing_summary_card.dart';
import '../widgets/market_countdown.dart';
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

  /// 지금 시각을 읽는 함수. 가격 유효 시간이 이 값을 본다.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listing ??= _load();
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
      showErrorSnackBar(context, e.message);
      // 거절의 이유가 매물 쪽에 있을 수 있다(그새 팔림·가격 불일치). 다시
      // 받아 와 화면이 지금 상태를 말하게 한다.
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = MarketHours.at(widget.clock());

    return Scaffold(
      backgroundColor: resalePageBackground,
      appBar: ResaleAppBar(
        title: ResaleStrings.purchaseTitle,
        trailing: hours.isOpen
            ? MarketCountdown(
                until: hours.nextBoundary,
                clock: widget.clock,
                semanticsLabel: ResaleStrings.openRemainingSemantics,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              )
            : null,
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
