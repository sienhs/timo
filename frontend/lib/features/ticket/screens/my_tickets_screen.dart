import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../shell/constants.dart';
import '../../shell/quick_menu_launcher.dart';
import '../../shell/widgets/app_bottom_nav_bar.dart';
import '../../shell/widgets/quick_menu_button.dart';
import '../constants.dart';
import '../models/my_ticket.dart';
import '../state/ticket_api_scope.dart';
import '../widgets/cancel_reservation_dialog.dart';
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
/// 양도 목록은 자리만 있고 비어 있다. 이유는 [TicketTabBar] 주석 참고.
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

  final _searchController = TextEditingController();
  int _tabIndex = 0;
  String _query = '';

  /// 개수를 탭에 띄우려면 본문 밖에서도 결과가 필요하다. [AsyncBoundary] 는
  /// 데이터를 안에 들고 있어 꺼낼 수 없으므로 여기에도 한 벌 기억해 둔다.
  _MyTicketsData? _loaded;

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
    } else {
      _data = null;
      _loaded = null;
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

  void _reload() {
    setState(() {
      _now = widget.clock();
      _data = _load();
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
      case TicketMoreAction.cancelReservation:
        await _cancelReservation(ticket);
    }
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
        // 조회가 없다 = 로그인 상태가 아니다([didChangeDependencies]).
        child: data == null
            ? _loginPrompt()
            : Column(
                children: [
                  TicketTabBar(
                    selectedIndex: _tabIndex,
                    // 양도 목록은 아직 셀 데이터가 없어 null — 숫자 없이 이름만.
                    counts: loaded == null
                        ? null
                        : [
                            loaded.upcoming(_now).length,
                            loaded.past(_now).length,
                            null,
                          ],
                    onSelected: (index) => setState(() => _tabIndex = index),
                  ),
                  Expanded(
                    child: AsyncBoundary<_MyTicketsData>(
                      future: data,
                      onRetry: _reload,
                      loading: const TicketListSkeleton(),
                      builder: (context, data) => _body(data),
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
      // 양도 목록. 자리만 두고 내용은 양도마켓 작업에서 채운다([TicketTabBar]
      // 주석). 그래서 이 화면의 조회 결과([_MyTicketsData])와 아직 무관하다.
      _ => const TicketEmptyView(message: TicketStrings.emptyListings),
    };
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
