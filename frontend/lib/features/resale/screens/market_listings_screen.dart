import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../constants.dart';
import '../models/listing.dart';
import '../models/market_concert.dart';
import '../models/market_hours.dart';
import '../models/market_sort.dart';
import '../state/resale_api_scope.dart';
import '../widgets/listing_row_card.dart';
import '../widgets/market_countdown.dart';
import '../widgets/resale_app_bar.dart';
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

  /// 지금 시각을 읽는 함수. 상단 바의 마감 시간이 이 값을 본다.
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

  @override
  Widget build(BuildContext context) {
    final hours = MarketHours.at(widget.clock());

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: ResaleAppBar(
        title: widget.concert.title,
        trailing: hours.isOpen
            ? MarketCountdown(
                until: hours.nextBoundary,
                clock: widget.clock,
                // 마감하면 첫 화면으로 돌려보낸다. 그 화면이 닫힘 상태를 다시
                // 판정해 안내와 다음 오픈 시간을 보여 준다.
                onElapsed: () => Navigator.maybePop(context),
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
        child: Column(
          children: [
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
        onTap: () => _openPurchase(sorted[index]),
      ),
    );
  }
}
