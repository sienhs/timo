import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../resale/models/my_trade.dart';
import '../../resale/state/resale_api_scope.dart';
import '../../shell/constants.dart';
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
import '../widgets/ticket_search_field.dart';
import '../widgets/ticket_tab_bar.dart';
import '../widgets/upcoming_ticket_card.dart';

/// 내 티켓. 예정 공연 · 지난 공연 · 양도 목록 세 탭이다.
///
/// 예정과 지난은 **같은 응답**을 공연 날짜로 가른다. 서버에 그 필터가 없어서
/// 한 번 받아 화면이 나눈다.
///
/// 양도 목록은 **다른 조회**다. 마켓 API 의 내 거래 내역에서 내가 올린 매물만
/// 골라 그린다. 예매 목록과 따로 받는 이유는 한쪽이 실패해도 다른 쪽은 보여야
/// 해서다 — 마켓이 안 되는데 내 티켓까지 안 보이면 안 된다.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key, this.clock = DateTime.now});

  /// 지금 시각을 읽는 함수. D-day 와 QR 창 판정이 이 값을 본다.
  ///
  /// 테스트에서 시각을 고정하려고 받는다(공연 상세 화면과 같은 방식이다).
  /// 목 데이터도 같은 시각을 받아야 배지가 흔들리지 않는다.
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

  final _searchController = TextEditingController();
  int _tabIndex = 0;
  String _query = '';

  /// 개수를 탭에 띄우려면 본문 밖에서도 결과가 필요하다. [AsyncBoundary] 는
  /// 데이터를 안에 들고 있어 꺼낼 수 없으므로 여기에도 한 벌 기억해 둔다.
  _MyTicketsData? _loaded;

  /// 양도 목록 탭의 개수용. [_loaded] 와 같은 이유로 한 벌 기억해 둔다.
  List<MyTrade>? _sales;

  /// 목록을 그리는 기준 시각. D-day 와 QR 창이 이 값을 본다.
  ///
  /// 카드마다 `DateTime.now()` 를 부르면 같은 목록 안에서 기준이 미세하게
  /// 갈린다. 새로 고칠 때 함께 갱신한다.
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

  /// 내 거래 내역에서 판매만 남긴다. 구매(양도로 산 티켓)는 이 탭 것이 아니다 —
  /// 시안이 그렇고, 산 티켓은 "내 티켓" 이라 예정 공연 탭이 맞다(지금 서버가
  /// 못 주는 사정은 [MyTrade] 주석). 팔린 것·내린 것은 남긴다. 지우면 결과가
  /// 안 보인다.
  Future<List<MyTrade>> _loadTrades() async {
    final trades = await ResaleApiScope.of(context).fetchMyTrades();
    final sales = trades.where((trade) => trade.isSale).toList();
    if (mounted) setState(() => _sales = sales);
    return sales;
  }

  void _reload() {
    setState(() {
      _now = widget.clock();
      _data = _load();
      _trades = _loadTrades();
    });
  }

  /// 안내 스낵바. 하단 바와 원형 버튼에 가리지 않게 그 위로 띄운다.
  void _notify(String message) {
    showInfoSnackBar(
      context,
      message,
      bottomMargin:
          ShellMetrics.barHeight + ShellMetrics.fabProtrusion + _snackBarGap,
    );
  }

  /// 카드 더보기(⋮). 고른 것이 있으면 그 흐름으로 이어간다.
  Future<void> _openMore(MyTicket ticket) async {
    final action = await showTicketMoreSheet(
      context,
      ticket: ticket,
      now: _now,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case TicketMoreAction.registerListing:
        await _openRegister();
      case TicketMoreAction.cancelReservation:
        await _cancelReservation(ticket);
    }
  }

  /// 양도마켓의 등록 화면으로 간다. 등록하고 돌아왔으면 목록을 다시 받는다 —
  /// 양도 목록 탭에 새 매물이 보여야 한다.
  ///
  /// 누른 티켓을 미리 골라 두지 않는다. 등록이 받는 티켓 번호와 예매 번호가
  /// 다른 값이라(`ListableTicket` 주석) 지금은 이어 줄 수 없다. 서버가 예매
  /// 응답에 티켓 번호를 실어 주면 그때 등록 화면에 인자를 얹는다.
  ///
  /// 결과 타입을 `pushNamed<bool>` 로 못 박지 않는다. 라우트 등록부가 만드는
  /// 라우트는 `Route<dynamic>` 이라 타입을 지정하면 실기기에서 캐스팅 예외로
  /// 눌러도 아무 일이 안 일어난다(마켓 첫 화면과 같은 사정).
  Future<void> _openRegister() async {
    final registered = await Navigator.pushNamed(
      context,
      AppRoutes.resaleRegister,
    );
    if (registered == true && mounted) _reload();
  }

  /// 예매를 취소한다.
  ///
  /// 확인을 받고 서버에 보낸 뒤 목록을 **다시 받는다.** 카드 하나만 회색으로
  /// 바꿔치기하면 화면이 서버와 어긋날 수 있다 — 취소가 성공해도 그 사이에
  /// 다른 티켓이 달라졌을 수 있고, 실패했다면 아무것도 바뀌지 않아야 한다.
  ///
  /// 서버가 거절하면(예: 그새 24시간 안으로 들어옴) 그 문구를 그대로 띄운다.
  /// 화면이 미리 걸러도 시점 차이로 통과할 수 있어 최종 판정은 서버 몫이다.
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
    // 성공 안내를 따로 띄우지 않는다. 목록을 다시 받으면 그 자리에 "예매를
    // 취소했어요" 회색 카드가 남아 결과가 이미 보인다. 스낵바까지 띄우면 같은
    // 말을 두 번 하면서 카드를 잠깐 가린다.
    _reload();
  }

  /// 양도 등록을 취소한다(매물을 내린다). 예매 취소와 같은 흐름이다.
  ///
  /// 확인을 받고 서버에 보낸 뒤 목록을 **다시 받는다.** 카드 하나만 바꿔치기하지
  /// 않는 이유도 같다 — 그 사이 팔렸을 수 있고, 실패했다면 아무것도 바뀌지
  /// 않아야 한다. 서버가 거절하면(그새 팔렸거나 이미 내려감) 그 문구를 그대로
  /// 띄운다. 성공 안내는 따로 없다. 다시 받은 목록에 "등록을 취소했어요" 회색
  /// 카드가 남는다.
  Future<void> _delist(MyTrade trade) async {
    final confirmed = await showDelistListingDialog(context, trade: trade);
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

  /// 하단 바의 홈·마이페이지로 간다.
  ///
  /// 이 화면은 빠른 메뉴에서 얹힌 것이라 아래에 셸이 깔려 있다. 그런데
  /// `popUntil` 로는 셸에 "어느 탭을 열지" 를 알릴 방법이 없어, 셸을 탭을 지정해
  /// 새로 세운다. 홈은 앱의 뿌리라 그 위에 쌓인 것을 전부 걷어내는 게 맞다 —
  /// 홈에서 뒤로 가기를 누르면 앱이 닫혀야지 티켓 목록으로 돌아가면 이상하다.
  ///
  /// 셸이 새로 만들어져 홈의 스크롤 위치는 초기화된다. 그걸 지키려면 탭 상태를
  /// 앱 최상단의 컨트롤러로 올려야 하는데, 하단 바를 다는 화면이 아직 둘뿐이라
  /// 그만한 장치를 두지 않았다. 세 번째가 생기면 그때 올린다.
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
                            // 판매중인 것만 센다. 팔렸거나 내린 매물은 "지금
                            // 올라가 있는 매물" 이 아니다. 아직 안 도착했으면
                            // 숫자 없이 이름만.
                            _sales?.where((trade) => trade.isOnSale).length,
                          ],
                    onSelected: (index) => setState(() => _tabIndex = index),
                  ),
                  Expanded(
                    // 두 조회를 각각 기다린다. 둘 다 살려 두고 하나만 보이는
                    // 이유는, 탭을 오갈 때마다 경계 위젯을 새로 세우면 이미
                    // 받아 둔 결과인데도 뼈대 카드가 한 프레임 스치기 때문이다.
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
      // 시안에 하단 바가 그려져 있다. 이 화면은 셸 위에 얹힌 것이라 셸의 바가
      // 가려지므로 여기서 한 벌 더 단다. 어느 탭도 고르지 않은 상태(-1)라
      // 홈·마이페이지 둘 다 회색이다 — 시안도 그렇다.
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
          onShowDetail: () =>
              _notify(TicketStrings.notReady(TicketStrings.showDetail)),
          // 취소가 안 되는 티켓에도 더보기를 연다. 시트가 이유를 알려준다 —
          // 버튼 자체를 지우면 왜 못 하는지 물어볼 자리가 없다.
          onMore: ticket.status.isUsable ? () => _openMore(ticket) : null,
        ),
      ),
      1 => _ticketList(
        tickets: data.past(_now),
        emptyMessage: TicketStrings.emptyPast,
        cardBuilder: (ticket) => PastTicketCard(
          ticket: ticket,
          onCreateCollectible: () =>
              _notify(TicketStrings.notReady(TicketStrings.createCollectible)),
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
        padding: const EdgeInsets.symmetric(
          horizontal: TicketMetrics.horizontalPadding,
          vertical: TicketMetrics.cardGap,
        ),
        itemCount: sales.length,
        itemBuilder: (_, index) => ListingCard(
          trade: sales[index],
          now: _now,
          // 가격 수정 API 가 아직 없다. 버튼은 시안대로 두고 안내만 띄운다 —
          // 상세정보 보기·소장품 만들기와 같은 처리다.
          onEditPrice: () =>
              _notify(TicketStrings.notReady(TicketStrings.editPrice)),
          onDelist: () => _delist(sales[index]),
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
            child: TicketSearchField(
              controller: _searchController,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: TicketMetrics.horizontalPadding,
                      vertical: TicketMetrics.cardGap,
                    ),
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

/// 안내 스낵바와 하단 바(원형 버튼 포함) 사이 틈.
const _snackBarGap = 12.0;

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

  /// 이미 끝난 공연. 회수된 티켓은 뺀다. 가지 않은 공연이라 소장품을 만들 수 없다.
  List<MyTicket> past(DateTime now) => tickets
      .where((ticket) => ticket.isPast(now) && !ticket.status.isVoided)
      .toList();
}
