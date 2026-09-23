import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../memory/screens/creator_screen.dart';
import '../../memory/screens/memory_page_route.dart';
import '../../memory/state/memory_concert_api_scope.dart';
import '../../resale/models/market_hours.dart';
import '../../resale/models/my_trade.dart';
import '../../resale/state/resale_api_scope.dart';
import '../../resale/widgets/listing_price_sheet.dart';
import '../../shell/quick_menu_launcher.dart';
import '../../shell/widgets/app_bottom_nav_bar.dart';
import '../../shell/widgets/quick_menu_button.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import '../state/ticket_api_scope.dart';
import '../widgets/cancel_reservation_dialog.dart';
import '../widgets/delist_listing_dialog.dart';
import '../widgets/listing_card.dart';
import '../widgets/past_ticket_card.dart';
import '../widgets/ticket_more_sheet.dart';
import '../widgets/ticket_empty_view.dart';
import '../widgets/ticket_list_skeleton.dart';
import '../widgets/ticket_tab_bar.dart';
import '../widgets/upcoming_ticket_card.dart';

/// 내 티켓. 예정 공연 · 지난 공연 · 양도 목록 세 탭이다. 예정과 지난은 같은
/// 응답(내 티켓 목록)을 공연 날짜로 가르고, 양도 목록은 마켓 API 의 내 거래
/// 내역에서 내가 올린 매물만 골라 그린다 — 한쪽이 실패해도 다른 쪽은 보여야 한다.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key, this.clock = DateTime.now});

  /// 지금 시각을 읽는 함수. D-day 와 QR 창 판정이 이 값을 본다. 테스트에서
  /// 시각을 고정하려고 받는다.
  final DateTime Function() clock;

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  /// 진행 중인 조회. 로그인 상태가 아니면 null 이다 — 서버가 로그인한 회원의
  /// 주문만 주므로 비로그인으로는 부를 이유가 없고, 부르면 401 만 받는다.
  Future<_MyTicketsData>? _data;

  /// 양도 목록 탭의 조회. 시작하고 버리는 조건은 [_data] 와 같다.
  Future<List<MyTrade>>? _trades;

  /// 카드에서 시작한 흐름(더보기 · 가격 수정 · 등록 취소)이 도는 중. 시트도
  /// 다이얼로그도 여는 데 한 프레임이 걸려, 그 사이 다시 눌리면 시트가 겹치고
  /// 요청도 두 번 나가 [_guard] 로 막는다. 시트가 화면을 덮으므로 setState 는 안 한다.
  bool _acting = false;

  final _searchController = TextEditingController();
  int _tabIndex = 0;
  String _query = '';

  /// 개수를 탭에 띄우려면 본문 밖에서도 결과가 필요하다. [AsyncBoundary] 는
  /// 데이터를 안에 들고 있어 꺼낼 수 없으므로 여기에도 한 벌 기억해 둔다.
  _MyTicketsData? _loaded;

  /// 양도 목록 탭의 개수용. [_loaded] 와 같은 이유로 한 벌 기억해 둔다.
  List<MyTrade>? _sales;

  /// 마켓 운영 상태. 열려 있는 동안은 가격을 못 바꾸므로(서버 409) 가격 수정
  /// 버튼을 뺀다. 못 받았으면 null — 버튼은 두고 최종 판정은 서버에 맡긴다.
  MarketHours? _hours;

  /// 소장품 카탈로그를 받아 보는 중인 티켓([MyTicket.ticketId]). 그 카드의
  /// 버튼에만 동그라미가 돈다. 한 번에 하나다 — 두 장을 동시에 눌러도 먼저
  /// 누른 쪽만 간다.
  int? _creatingFor;

  /// 목록을 그리는 기준 시각. D-day 와 QR 창이 이 값을 본다. 카드마다
  /// `DateTime.now()` 를 부르면 기준이 미세하게 갈려 새로 고칠 때 함께 갱신한다.
  late DateTime _now;

  /// 충전 화면과 같은 판단. 스코프가 없으면(스코프 없이 띄우는 테스트) 비로그인.
  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void initState() {
    super.initState();
    _now = widget.clock();
  }

  /// 로그인한 채로 들어왔거나 이 화면에서 로그인하고 돌아왔을 때 목록을 받아
  /// 온다. 로그아웃되면(토큰 만료로 재발급까지 실패한 경우 포함) 들고 있던
  /// 목록을 버린다 — 그러면 본문이 로그인 안내로 바뀐다. 충전 화면과 같은 방식.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoggedIn) {
      _data ??= _load();
      _trades ??= _loadTrades();
    } else {
      _data = null;
      _loaded = null;
      _trades = null;
      _sales = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_MyTicketsData> _load() async {
    final tickets = await TicketApiScope.of(context).fetchMyTickets();
    final data = _MyTicketsData(tickets: tickets);
    // 개수 표시는 빌드 밖에서 읽어야 해서 여기서 기억해 둔다. build 중이 아니라
    // Future 안이므로 setState 로 다시 그려 준다.
    if (mounted) setState(() => _loaded = data);
    return data;
  }

  /// 내 거래 내역에서 판매만 남긴다. 양도로 산 티켓은 "내 티켓" 이라 예정 공연
  /// 탭 몫이다. 팔린 것·내린 것은 결과가 보이게 남긴다. 운영 상태도 함께 받되
  /// 안내용이라 못 받아도 목록은 그대로 보여 준다.
  Future<List<MyTrade>> _loadTrades() async {
    final api = ResaleApiScope.of(context);
    final trades = await api.fetchMyTrades();
    final sales = trades.where((trade) => trade.isSale).toList();
    MarketHours? hours;
    try {
      hours = await api.fetchMarketHours();
    } on ApiException {
      hours = null;
    }
    if (mounted) {
      setState(() {
        _sales = sales;
        _hours = hours;
      });
    }
    return sales;
  }

  void _reload() {
    setState(() {
      _now = widget.clock();
      _data = _load();
      _trades = _loadTrades();
    });
  }

  /// 안내 스낵바. 하단 바에 가리지 않게 그 위로 띄운다.
  void _notify(String message) {
    showInfoSnackBar(context, message, bottomMargin: snackBarGapAboveBar);
  }

  /// 카드에서 시작한 흐름을 한 번에 하나만 돌린다([_acting]). 흐름 안에서 서로를
  /// 부르는 것(더보기 → 등록 취소)은 이미 이 안이라 막히지 않는다.
  Future<void> _guard(Future<void> Function() action) async {
    if (_acting) return;
    _acting = true;
    try {
      await action();
    } finally {
      _acting = false;
    }
  }

  /// 카드 더보기(⋮). 고른 것이 있으면 그 흐름으로 이어간다. 매물은 시트를 열 때와
  /// 고른 뒤 두 번 찾는다 — 시트가 열린 사이 목록이 다시 와 그새 팔렸을 수 있다.
  Future<void> _openMore(MyTicket ticket) async {
    final action = await showTicketMoreSheet(
      context,
      ticket: ticket,
      now: _now,
      listingFound: _listingFor(ticket) != null,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case TicketMoreAction.registerListing:
        await _openRegister(ticket);
      case TicketMoreAction.cancelListing:
        if (_listingFor(ticket) case final trade?) {
          await _delist(trade);
        } else {
          // 시트를 열 때는 있었는데 고르는 사이 사라졌다. 이 자리에서 할 수
          // 있는 게 없으므로 이유만 알린다.
          _notify(TicketStrings.cancelListingUnknown);
        }
      case TicketMoreAction.cancelReservation:
        await _cancelReservation(ticket);
    }
  }

  /// 이 티켓으로 올려 둔 매물. 없으면 null. 티켓 응답에 매물 번호가 없고 매물
  /// 응답에 티켓 번호가 없어 공연·구역·행·번호로 맞춘다. 지금 올라가 있는 매물
  /// ([MyTrade.isOnSale])만 본다 — 내렸다 다시 올린 이력이 있어도 한 건이다.
  MyTrade? _listingFor(MyTicket ticket) {
    final sales = _sales;
    if (sales == null) return null;
    for (final trade in sales) {
      if (!trade.isOnSale) continue;
      if (trade.concertId == ticket.concertId &&
          trade.sectionName == ticket.sectionName &&
          trade.seatRow == ticket.seatRow &&
          trade.seatNumber == ticket.seatNumber) {
        return trade;
      }
    }
    return null;
  }

  /// 양도마켓의 등록 화면으로 간다. 누른 티켓의 [MyTicket.ticketId] 를 얹어 미리
  /// 골라 두게 하고, 등록하고 돌아왔으면 목록을 다시 받는다. 결과 타입을
  /// `pushNamed<bool>` 로 못 박지 않는다 — `Route<dynamic>` 이라 실기기에서 캐스팅 예외가 난다.
  Future<void> _openRegister(MyTicket ticket) async {
    final registered = await Navigator.pushNamed(
      context,
      AppRoutes.resaleRegister,
      arguments: ticket.ticketId,
    );
    if (registered == true && mounted) _reload();
  }

  /// 지난 공연 카드의 '공연 추억 만들기'. 그 티켓의 소장품 제작 화면을 연다.
  ///
  /// 제작 화면은 공연 하나를 받아야 공연 고르는 단계를 건너뛴다. 카드가 든
  /// 것은 티켓 정보뿐이라 소장품 카탈로그에서 같은 티켓 번호의 줄을 찾아
  /// 넘긴다. 카탈로그를 여기서 미리 받아 두지 않는 이유는 지난 공연 탭을 여는
  /// 사람 대부분이 이 버튼을 누르지 않아서다 — 누른 사람만 기다린다.
  ///
  /// 카탈로그가 답을 셋으로 가른다.
  ///
  /// | 카탈로그 | 가는 곳 |
  /// | --- | --- |
  /// | 그 티켓이 있고 소장품은 없음 | 그 공연 제작 화면 |
  /// | 소장품이 이미 있음 | 컬렉션 (한 티켓에 소장품은 하나다) |
  /// | 그 티켓이 없음 | 안내 한 줄 — 입장을 마친 티켓만 카탈로그에 든다 |
  ///
  /// 기기에 만들다 만 임시본이 있으면 제작 화면이 덮어쓴다. 컬렉션 화면도
  /// 같은 규칙이라 여기서 따로 막지 않는다.
  ///
  /// 두 번 눌리는 것은 [_guard] 가 아니라 [_creatingFor] 가 막는다. 그 값이
  /// 버튼의 동그라미까지 함께 맡아서다 — 시트·다이얼로그와 달리 이 흐름은
  /// 기다리는 동안 화면을 덮지 않아, 눌린 버튼이 계속 보인다.
  Future<void> _createCollectible(MyTicket ticket) async {
    if (_creatingFor != null) return;
    final api = MemoryConcertApiScope.of(context);
    setState(() => _creatingFor = ticket.ticketId);
    try {
      final concerts = await api.getConcerts();
      if (!mounted) return;
      // 카탈로그의 티켓 번호는 문자열이다(서버가 준 번호를 그대로 담는다).
      final concert = concerts
          .where((c) => c.ticketId == '${ticket.ticketId}')
          .firstOrNull;
      if (concert == null) {
        _notify(TicketStrings.collectibleNotEntered);
        return;
      }
      if (concert.goodsId != null) {
        _notify(TicketStrings.collectibleAlready);
        await Navigator.pushNamed(context, AppRoutes.collection);
        return;
      }
      await Navigator.push(
        context,
        memoryRoute<void>(CreatorScreen(initialConcert: concert)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _creatingFor = null);
    }
  }

  /// 예매를 취소한다. 확인을 받고 서버에 보낸 뒤 목록을 다시 받는다 — 카드 하나만
  /// 회색으로 바꿔치기하면 서버와 어긋날 수 있다. 서버가 거절하면(그새 24시간
  /// 안으로 들어옴 등) 그 문구를 그대로 띄운다. 최종 판정은 서버 몫이다.
  Future<void> _cancelReservation(MyTicket ticket) async {
    final confirmed = await showCancelReservationDialog(
      context,
      ticket: ticket,
    );
    if (!confirmed || !mounted) return;

    // await 앞에서 context 를 쓰는 것은 다 끝내 둔다.
    final api = TicketApiScope.of(context);
    try {
      await api.cancelReservation(ticket.reservationId);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
      return;
    }
    if (!mounted) return;
    // 성공 안내는 따로 없다. 다시 받은 목록에 "예매를 취소했어요" 회색 카드가
    // 남아 결과가 이미 보인다.
    _reload();
  }

  /// 양도 등록을 취소한다(매물을 내린다). 예매 취소와 같은 흐름이다 — 확인을
  /// 받고 서버에 보낸 뒤 목록을 다시 받고, 거절되면 서버 문구를 그대로 띄운다.
  /// 성공 안내는 따로 없다. 다시 받은 목록에 "등록을 취소했어요" 카드가 남는다.
  Future<void> _delist(MyTrade trade) async {
    final confirmed = await showDelistListingDialog(
      context,
      concertTitle: trade.concertTitle,
      seatLabel: trade.seatLabel,
      price: trade.price,
    );
    if (!confirmed || !mounted) return;

    final api = ResaleApiScope.of(context);
    try {
      await api.cancelListing(trade.listingId);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
      return;
    }
    if (!mounted) return;
    _reload();
  }

  /// 등록가를 바꾼다. 등록 취소와 같은 흐름이다 — 시트에서 새 값을 받고 서버에
  /// 보낸 뒤 목록을 다시 받는다. 상한은 등록 시점 정가([MyTrade.faceValue])로
  /// 시트가 먼저 거르고 서버도 같은 자리에서 거절한다.
  Future<void> _editPrice(MyTrade trade) async {
    final price = await showListingPriceSheet(
      context,
      currentPrice: trade.price,
      faceValue: trade.faceValue,
    );
    if (price == null || !mounted) return;

    final api = ResaleApiScope.of(context);
    try {
      await api.updateListingPrice(listingId: trade.listingId, price: price);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
      return;
    }
    if (!mounted) return;
    // 바뀐 숫자는 카드에 남지만 등록 취소의 회색 카드만큼 눈에 띄지 않아
    // 한 줄 알린다.
    _notify(TicketStrings.priceUpdated);
    _reload();
  }

  /// 하단 바의 홈·마이페이지로 간다. 이 화면은 셸 위에 얹힌 것인데 `popUntil`
  /// 로는 셸에 어느 탭을 열지 알릴 수 없어, 탭을 지정해 셸을 새로 세운다. 그래서
  /// 홈의 스크롤 위치는 초기화된다.
  void _goToShellTab(int index) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
      arguments: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _loaded;
    final data = _data;
    final trades = _trades;

    return Scaffold(
      // 키보드가 올라와도 본문을 줄이지 않는다. 줄이면 원형 버튼이 키보드 위로
      // 따라 올라온다. 대신 목록 아래 여백에 키보드 높이를 더한다([_listPadding]).
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(TicketStrings.screenTitle),
        actions: [
          IconButton(
            onPressed: () =>
                _notify(TicketStrings.notReady(TicketStrings.notifications)),
            icon: const Icon(Icons.notifications_none),
            tooltip: TicketStrings.notifications,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        // 조회가 없다 = 로그인 상태가 아니다([didChangeDependencies]). 두 조회는
        // 함께 시작하고 함께 버려지므로 하나만 봐도 되지만, 타입을 좁히려고 둘 다 본다.
        child: data == null || trades == null
            ? _loginPrompt()
            : Column(
                children: [
                  TicketTabBar(
                    selectedIndex: _tabIndex,
                    counts: loaded == null
                        ? null
                        : [
                            loaded.upcoming(_now).length,
                            loaded.past(_now).length,
                            // 판매중인 것만 센다. 팔렸거나 내린 매물은 "지금 올라가
                            // 있는 매물" 이 아니다. 아직 안 도착했으면 이름만.
                            _sales?.where((trade) => trade.isOnSale).length,
                          ],
                    onSelected: (index) => setState(() => _tabIndex = index),
                  ),
                  Expanded(
                    // 두 조회를 각각 기다린다. 탭을 오갈 때마다 경계 위젯을 새로
                    // 세우면 받아 둔 결과인데도 뼈대 카드가 한 프레임 스친다.
                    child: IndexedStack(
                      index: _tabIndex == _listingsTab ? 1 : 0,
                      sizing: StackFit.expand,
                      children: [
                        AsyncBoundary<_MyTicketsData>(
                          future: data,
                          onRetry: _reload,
                          loading: const TicketListSkeleton(),
                          builder: (context, data) => _body(data),
                        ),
                        AsyncBoundary<List<MyTrade>>(
                          future: trades,
                          onRetry: _reload,
                          loading: const TicketListSkeleton(),
                          builder: (context, sales) => _listingList(sales),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      // 셸 위에 얹힌 화면이라 셸의 하단 바가 가려져 여기서 한 벌 더 단다. 어느
      // 탭도 고르지 않은 상태(-1)라 홈·마이페이지 둘 다 회색이다 — 시안도 그렇다.
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: -1,
        onTabSelected: _goToShellTab,
        onQuickMenuPressed: () => openQuickMenu(context),
      ),
      floatingActionButton: QuickMenuButton(
        onPressed: () => openQuickMenu(context),
      ),
      floatingActionButtonLocation: quickMenuButtonLocation,
    );
  }

  /// 비로그인 안내. 탭 바도 내지 않는다 — 세어 줄 것이 없는 탭 이름만 남으면
  /// 빈 화면처럼 읽힌다. 문구와 버튼은 마이페이지·충전 화면과 같은 꼴이다.
  /// 로그인 화면에서 돌아오면 세션이 바뀌어 [didChangeDependencies] 가 목록을 부른다.
  Widget _loginPrompt() => TicketEmptyView(
    message: TicketStrings.loginPrompt,
    actionLabel: AuthStrings.login,
    onAction: () => Navigator.pushNamed(context, AppRoutes.login),
  );

  Widget _body(_MyTicketsData data) {
    return switch (_tabIndex) {
      0 => _ticketList(
        tickets: data.upcoming(_now),
        emptyMessage: TicketStrings.emptyUpcoming,
        emptyActionLabel: TicketStrings.emptyUpcomingAction,
        // 홈이 아래에 깔려 있다. 새 화면을 얹는 대신 이 화면을 닫는다.
        onEmptyAction: () => Navigator.maybePop(context),
        cardBuilder: (ticket) => UpcomingTicketCard(
          ticket: ticket,
          now: _now,
          onEnterQr: () => Navigator.pushNamed(
            context,
            AppRoutes.entryQr,
            arguments: ticket,
          ),
          // 공연 상세로 보낸다. 티켓이 든 것은 좌석과 시각뿐이라, 그 밖을
          // 알고 싶으면 공연 쪽이다. 받는 번호는 티켓이 아니라 공연 번호다.
          onShowDetail: () => Navigator.pushNamed(
            context,
            AppRoutes.showDetail,
            arguments: ticket.concertId,
          ),
          // 취소가 안 되는 티켓·양도 등록 중인 티켓에도 더보기를 열어 시트가
          // 이유를 알려준다. 발행 중·입장 완료·회수·환불은 할 일이 없어 안 연다.
          onMore: ticket.isHeld ? () => _guard(() => _openMore(ticket)) : null,
        ),
      ),
      1 => _ticketList(
        tickets: data.past(_now),
        emptyMessage: TicketStrings.emptyPast,
        cardBuilder: (ticket) => PastTicketCard(
          ticket: ticket,
          creating: _creatingFor == ticket.ticketId,
          onCreateCollectible: () => _createCollectible(ticket),
        ),
      ),
      // 양도 목록은 다른 조회가 그린다([_listingList]). 이 경계는 그때 가려져
      // 있으므로 빈 상자만 둔다.
      _ => const SizedBox.shrink(),
    };
  }

  /// 양도 목록 탭. 내가 올린 매물 카드. 검색 칸은 없다 — 올린 매물이 걸러 볼
  /// 만큼 쌓이는 일이 없다.
  Widget _listingList(List<MyTrade> sales) {
    if (sales.isEmpty) {
      return const TicketEmptyView(message: TicketStrings.emptyListings);
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      color: AppColors.primary,
      child: ListView.builder(
        padding: _listPadding(context),
        itemCount: sales.length,
        itemBuilder: (_, index) => ListingCard(
          trade: sales[index],
          now: _now,
          // 마켓이 열려 있는 동안은 가격이 고정이라 버튼을 안 낸다.
          onEditPrice: _hours?.isOpen ?? false
              ? null
              : () => _guard(() => _editPrice(sales[index])),
          onDelist: () => _guard(() => _delist(sales[index])),
        ),
      ),
    );
  }

  /// 예정·지난 탭. 검색 칸은 걸러 볼 만큼 쌓였을 때만 낸다.
  Widget _ticketList({
    required List<MyTicket> tickets,
    required String emptyMessage,
    required Widget Function(MyTicket ticket) cardBuilder,
    String? emptyActionLabel,
    VoidCallback? onEmptyAction,
  }) {
    final showSearch = tickets.length >= TicketMetrics.searchVisibleFrom;
    final matched = showSearch ? _filter(tickets, (t) => t.title) : tickets;

    return Column(
      children: [
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TicketMetrics.horizontalPadding,
              TicketMetrics.cardGap,
              TicketMetrics.horizontalPadding,
              0,
            ),
            child: AppSearchField(
              controller: _searchController,
              hintText: TicketStrings.searchHint,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        Expanded(
          child: matched.isEmpty
              ? TicketEmptyView(
                  // 걸러서 비었으면 "티켓이 없다" 가 아니라 "찾는 게 없다" 다.
                  message: _query.trim().isEmpty
                      ? emptyMessage
                      : TicketStrings.searchEmpty(_query.trim()),
                  actionLabel: _query.trim().isEmpty ? emptyActionLabel : null,
                  onAction: onEmptyAction,
                )
              : RefreshIndicator(
                  onRefresh: () async => _reload(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: _listPadding(context),
                    itemCount: matched.length,
                    itemBuilder: (_, index) => cardBuilder(matched[index]),
                  ),
                ),
        ),
      ],
    );
  }

  List<T> _filter<T>(List<T> items, String Function(T) titleOf) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return items;
    return items
        .where((item) => titleOf(item).toLowerCase().contains(needle))
        .toList();
  }
}

/// 양도 목록 탭의 자리. [TicketTabBar.labels] 순서다.
const _listingsTab = 2;

/// 두 탭이 나눠 쓰는 한 번의 조회 결과.
class _MyTicketsData {
  const _MyTicketsData({required this.tickets});

  final List<MyTicket> tickets;

  /// 아직 안 지난 공연. 취소된 티켓도 여기 남는다 — 결과를 보여 줘야 하고,
  /// 지난 공연 탭에 섞이면 "다녀온 공연" 으로 읽힌다.
  List<MyTicket> upcoming(DateTime now) =>
      tickets.where((ticket) => !ticket.isPast(now)).toList();

  /// 이미 끝난 공연. 회수·환불된 티켓은 뺀다. 가지 않은 공연이라 소장품을
  /// 만들 수 없다.
  List<MyTicket> past(DateTime now) => tickets
      .where((ticket) => ticket.isPast(now) && !ticket.isVoided)
      .toList();
}

/// 카드 목록의 여백. 키보드가 열려 있으면 그 높이만큼 아래를 더 띄운다 —
/// Scaffold 가 본문을 줄여 주지 않기 때문이다.
EdgeInsets _listPadding(BuildContext context) => EdgeInsets.fromLTRB(
  TicketMetrics.horizontalPadding,
  TicketMetrics.cardGap,
  TicketMetrics.horizontalPadding,
  TicketMetrics.cardGap + MediaQuery.viewInsetsOf(context).bottom,
);
