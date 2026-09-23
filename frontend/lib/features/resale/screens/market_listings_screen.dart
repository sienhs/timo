import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../ticket/widgets/delist_listing_dialog.dart';
import '../constants.dart';
import '../models/listing.dart';
import '../models/market_concert.dart';
import '../models/market_sort.dart';
import '../state/resale_api_scope.dart';
import '../widgets/listing_row_card.dart';
import '../widgets/market_hours_countdown.dart';
import '../widgets/resale_app_bar.dart';
import '../widgets/resale_list_skeleton.dart';
import '../widgets/resale_empty_view.dart';
import '../widgets/sort_tab_row.dart';

/// 공연 하나의 매물 목록.
///
/// 고른 공연을 통째로 받는다. 매물 응답에는 공연 정보가 없어(같은 공연의
/// 매물이라 반복해 실을 이유가 없다) 제목과 회차를 여기서 가져온다. 번호만
/// 받아 공연을 다시 조회하면 방금 목록에서 본 값을 한 번 더 받는 셈이다.
class MarketListingsScreen extends StatefulWidget {
  const MarketListingsScreen({
    super.key,
    required this.concert,
    this.clock = DateTime.now,
  });

  final MarketConcert concert;

  /// 기기 시각을 읽는 함수. 상단 바의 마감 시간이 서버 시각을 이어 셀 때 쓴다.
  final DateTime Function() clock;

  @override
  State<MarketListingsScreen> createState() => _MarketListingsScreenState();
}

class _MarketListingsScreenState extends State<MarketListingsScreen> {
  Future<List<Listing>>? _listings;
  ListingSort _sort = ListingSort.latest;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listings ??= _load();
  }

  Future<List<Listing>> _load() =>
      ResaleApiScope.of(context).fetchListings(widget.concert.concertId);

  // 화살표 함수로 쓰면 대입식의 값(Future)이 콜백의 반환값이 되어 setState 가
  // 거절한다. 블록으로 둔다.
  void _reload() {
    setState(() {
      _listings = _load();
    });
  }

  /// 매물을 고르면 내 것이냐에 따라 갈린다. 내 매물은 살 수 없고 내릴 수 있다.
  Future<void> _openListing(Listing listing) =>
      listing.mine ? _delist(listing) : _openPurchase(listing);

  /// 매물을 고르면 구매 확인으로 간다.
  ///
  /// 돌아오면 목록을 다시 받는다. 사고 왔든 그냥 나왔든, 보고 있던 사이에
  /// 남이 사 갔을 수 있다 — 매물에는 선점이 없다.
  Future<void> _openPurchase(Listing listing) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.resalePurchase,
      arguments: listing.listingId,
    );
    if (mounted) _reload();
  }

  /// 내 매물을 내린다. 내 티켓의 양도 목록 탭과 **같은 팝업·같은 요청**이다.
  ///
  /// 확인을 받고 서버에 보낸 뒤 목록을 다시 받는다. 카드 한 장을 빼지 않는
  /// 이유는 그 탭과 같다 — 그새 팔렸을 수 있고, 실패했다면 아무것도 바뀌지
  /// 않아야 한다. 서버가 거절하면(그새 팔렸거나 이미 내려감) 그 문구를 그대로
  /// 띄운다.
  ///
  /// 성공 안내는 따로 없다. 다시 받은 목록에서 그 줄이 사라져 결과가 이미
  /// 보인다 — 마켓은 올라가 있는 매물만 주기 때문이다.
  Future<void> _delist(Listing listing) async {
    final confirmed = await showDelistListingDialog(
      context,
      // 매물 응답에 공연 정보가 없다. 목록과 같은 자리에서 가져온다.
      concertTitle: widget.concert.title,
      seatLabel: listing.seatLabel,
      price: listing.price,
    );
    if (!confirmed || !mounted) return;

    try {
      await ResaleApiScope.of(context).cancelListing(listing.listingId);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
      return;
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      // 상단 바에 남은 시간을 적지 않는다(사용자 결정). 공연 목록 화면과 같다.
      appBar: ResaleAppBar(title: widget.concert.title),
      body: SafeArea(
        child: Column(
          children: [
            // 세는 일만 남긴다. 그리지는 않는다([Offstage]) — 마감하면 첫 화면으로
            // 돌려보내야 하고, 그 화면이 서버에 다시 물어 닫힘 안내와 다음 오픈
            // 시간을 보여 준다.
            Offstage(
              child: MarketClosingCountdown(
                clock: widget.clock,
                onElapsed: () => Navigator.maybePop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ResaleMetrics.horizontalPadding,
                4,
                ResaleMetrics.horizontalPadding,
                0,
              ),
              child: SortTabRow(
                labels: [for (final sort in ListingSort.values) sort.label],
                selectedIndex: ListingSort.values.indexOf(_sort),
                onSelected: (index) =>
                    setState(() => _sort = ListingSort.values[index]),
              ),
            ),
            Expanded(
              child: AsyncBoundary<List<Listing>>(
                future: _listings!,
                onRetry: _reload,
                loading: const ResaleListSkeleton(withPoster: false),
                builder: (context, listings) => _list(listings),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Listing> listings) {
    if (listings.isEmpty) {
      return const ResaleEmptyView(message: ResaleStrings.emptyListings);
    }

    final sorted = _sort.sorted(listings);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        ResaleMetrics.horizontalPadding,
        8,
        ResaleMetrics.horizontalPadding,
        8,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) => ListingRowCard(
        listing: sorted[index],
        performedAt: widget.concert.startAt,
        onTap: () => _openListing(sorted[index]),
      ),
    );
  }
}
