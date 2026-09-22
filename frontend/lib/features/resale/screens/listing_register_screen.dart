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
import '../models/listable_ticket.dart';
import '../models/listing_price.dart';
import '../state/resale_api_scope.dart';
import '../widgets/listable_ticket_card.dart';
import '../widgets/listing_price_editor.dart';
import '../widgets/resale_app_bar.dart';
import '../widgets/resale_bottom_bar.dart';
import '../widgets/resale_empty_view.dart';
import '../widgets/resale_search_field.dart';

/// 양도 등록. 티켓을 고르고(1단계) 판매가를 정해(2단계) 마켓에 올린다.
///
/// 두 단계를 한 화면에 둔 이유는 되돌아가기가 잦기 때문이다. 가격을 정하다
/// 다른 티켓을 고르러 돌아가는 일이 흔한데, 라우트를 나누면 그때마다 티켓
/// 목록을 다시 받게 된다.
///
/// 마켓이 닫혀 있어도 등록은 된다. 서버가 등록은 시간과 무관하게 받고, 닫힌
/// 시간에 올린 매물은 다음 오픈에 목록에 드러난다(백엔드 `MarketApi` 주석).
/// 그래서 이 화면에는 마감 시간도 운영 상태도 없다.
///
/// 등록에 성공하면 결과로 true 를 넘기며 닫힌다. 공연 목록이 그걸 받아 매물
/// 수를 다시 받는다.
class ListingRegisterScreen extends StatefulWidget {
  const ListingRegisterScreen({super.key, this.initialTicketId});

  /// 미리 골라 둘 티켓. 내 티켓 카드의 `양도 등록하기` 로 들어왔을 때 그 카드의
  /// 티켓 번호다 — 이미 어느 티켓인지 정하고 온 사람에게 다시 고르게 하지
  /// 않는다. 마켓 첫 화면의 버튼으로 들어왔으면 null 이라 고르기부터 한다.
  ///
  /// 목록에 없는 번호(이미 올렸거나 취소한 티켓)면 고르지 않은 채 목록을
  /// 보여 준다. 없는 티켓을 골라 둔 것처럼 보이면 안 된다.
  final int? initialTicketId;

  @override
  State<ListingRegisterScreen> createState() => _ListingRegisterScreenState();
}

/// 등록 화면이 지금 어느 단계인가.
enum _RegisterStep {
  /// 어느 티켓을 팔지 고른다.
  pickTicket,

  /// 얼마에 팔지 정한다.
  setPrice,
}

class _ListingRegisterScreenState extends State<ListingRegisterScreen> {
  Future<List<ListableTicket>>? _tickets;

  final _searchController = TextEditingController();
  final _priceController = TextEditingController();

  String _query = '';
  _RegisterStep _step = _RegisterStep.pickTicket;
  ListableTicket? _selected;

  /// [ListingRegisterScreen.initialTicketId] 를 이미 처리했나.
  bool _preselected = false;

  /// 등록 요청을 보내고 응답을 기다리는 중. 그동안 버튼을 잠가 같은 티켓이
  /// 두 번 올라가지 않게 한다.
  bool _submitting = false;

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  /// 지금 입력된 판매가. 고른 티켓이 없으면 상한도 없으므로 0 으로 둔다.
  ListingPrice get _price => ListingPrice.parse(
    _priceController.text,
    faceValue: _selected?.facePrice ?? 0,
  );

  @override
  void initState() {
    super.initState();
    // 금액이 바뀌면 안내 문구·슬라이더·버튼이 함께 바뀐다. 값은 컨트롤러
    // 하나뿐이라 여기서 다시 그려 주기만 하면 된다.
    _priceController.addListener(_onPriceChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoggedIn) {
      _tickets ??= _fetchTickets();
    } else {
      _tickets = null;
    }
  }

  /// 목록을 받고, 미리 고를 티켓이 있으면 그 자리에서 골라 가격 단계로 간다.
  ///
  /// 목록이 오기 전에는 고를 수 없어 여기서 한다. 처음 받을 때 한 번만이다 —
  /// 다시 받을 때([_reload])는 사용자가 이미 고른 것을 건드리지 않는다.
  Future<List<ListableTicket>> _fetchTickets() async {
    final tickets = await ResaleApiScope.of(context).fetchListableTickets();
    _preselect(tickets);
    return tickets;
  }

  void _preselect(List<ListableTicket> tickets) {
    final ticketId = widget.initialTicketId;
    if (ticketId == null || _preselected || !mounted) return;
    _preselected = true;

    for (final ticket in tickets) {
      if (ticket.ticketId != ticketId) continue;
      setState(() {
        _select(ticket);
        _step = _RegisterStep.setPrice;
      });
      return;
    }
  }

  @override
  void dispose() {
    _priceController.removeListener(_onPriceChanged);
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPriceChanged() => setState(() {});

  // 화살표 함수로 쓰면 대입식의 값(Future)이 콜백의 반환값이 되어 setState 가
  // 거절한다. 블록으로 둔다.
  void _reload() {
    setState(() {
      _tickets = _fetchTickets();
    });
  }

  /// 티켓을 고른다. 이미 고른 것을 다시 누르면 고르기를 무른다 — 잘못 누른
  /// 뒤에 되돌릴 방법이 없으면 화면을 나갔다 들어와야 한다.
  void _select(ListableTicket ticket) {
    setState(() {
      _selected = _selected?.ticketId == ticket.ticketId ? null : ticket;
      // 처음 값은 정가다. 얼마나 깎을지는 파는 사람이 정할 일이고, 앱이 임의로
      // 깎아 두면 그 값이 권장가처럼 읽힌다.
      _priceController.text = _selected == null
          ? ''
          : formatThousands(ticket.facePrice);
    });
  }

  Future<void> _submit() async {
    final ticket = _selected;
    final price = _price;
    if (ticket == null || _submitting || !price.canSubmit) return;

    setState(() => _submitting = true);
    final api = ResaleApiScope.of(context);
    try {
      await api.createListing(ticketId: ticket.ticketId, price: price.value);
      if (!mounted) return;
      // 스낵바를 먼저 띄운다. ScaffoldMessenger 는 라우트보다 위에 있어 이
      // 화면이 닫혀도 남아, 돌아간 공연 목록 위에서 보인다(충전 화면과 같다).
      showSuccessSnackBar(
        context,
        ResaleStrings.registerSucceeded,
        fitContent: true,
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 입력값은 그대로 둔다. 다시 누르면 같은 값으로 다시 보낸다.
      showErrorSnackBar(context, e.message);
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 가격을 정하는 중에 뒤로가기를 누르면 화면을 닫지 않고 티켓 고르기로
      // 되돌아간다. 두 단계가 한 라우트라 시스템 뒤로가기가 여기까지 온다.
      canPop: _step == _RegisterStep.pickTicket,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = _RegisterStep.pickTicket);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const ResaleAppBar(title: ResaleStrings.registerTitle),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: _body()),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_isLoggedIn) {
      return ResaleEmptyView(
        message: ResaleStrings.loginPrompt,
        showMascot: false,
        actionLabel: AuthStrings.login,
        onAction: () => Navigator.pushNamed(context, AppRoutes.login),
      );
    }

    return AsyncBoundary<List<ListableTicket>>(
      future: _tickets!,
      onRetry: _reload,
      builder: (context, tickets) => _step == _RegisterStep.pickTicket
          ? _ticketPicker(tickets)
          : _priceForm(),
    );
  }

  /// 고를 티켓이 하나도 안 남았을 때의 자리.
  ///
  /// 검색이 빗나간 것과 애초에 양도할 티켓이 없는 것을 갈라 둔다. 다음에 할
  /// 일이 다르기 때문이다 — 검색은 검색어를 지우면 되지만, 티켓이 없는 쪽은
  /// 이 화면에서 할 수 있는 일이 없다. 그 자리에서 뒤로가기 말곤 길이 없으면
  /// 막다른 길이라, 예매 쪽으로 보낸다.
  Widget _emptyPicker() {
    final keyword = _query.trim();
    if (keyword.isNotEmpty) {
      return ResaleEmptyView(message: ResaleStrings.searchEmpty(keyword));
    }

    return ResaleEmptyView(
      message: ResaleStrings.emptyTickets,
      actionLabel: ResaleStrings.emptyTicketsAction,
      onAction: () => Navigator.pushNamed(context, AppRoutes.allShows),
    );
  }

  /// 1단계. 검색 칸과 내 티켓 목록.
  Widget _ticketPicker(List<ListableTicket> tickets) {
    final matched = tickets
        .where((ticket) => ticket.concertTitle.contains(_query.trim()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ResaleMetrics.horizontalPadding,
            8,
            ResaleMetrics.horizontalPadding,
            8,
          ),
          child: ResaleSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: matched.isEmpty
              ? _emptyPicker()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ResaleMetrics.horizontalPadding,
                  ),
                  itemCount: matched.length,
                  itemBuilder: (context, index) => ListableTicketCard(
                    ticket: matched[index],
                    selected: _selected?.ticketId == matched[index].ticketId,
                    onTap: () => _select(matched[index]),
                  ),
                ),
        ),
      ],
    );
  }

  /// 2단계. 고른 티켓 한 장과 판매가.
  Widget _priceForm() {
    final ticket = _selected!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        ResaleMetrics.horizontalPadding,
        8,
        ResaleMetrics.horizontalPadding,
        16,
      ),
      children: [
        ListableTicketCard(ticket: ticket, selected: true, showFacePrice: true),
        const SizedBox(height: 12),
        ListingPriceEditor(
          controller: _priceController,
          price: _price,
          onSliderChanged: (value) =>
              _priceController.text = formatThousands(value),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    if (!_isLoggedIn) {
      return const ResaleBottomBar(
        child: ResaleActionButton(
          label: ResaleStrings.registerNext,
          onPressed: null,
        ),
      );
    }

    if (_step == _RegisterStep.pickTicket) {
      return ResaleBottomBar(
        child: ResaleActionButton(
          label: ResaleStrings.registerNext,
          onPressed: _selected == null
              ? null
              : () => setState(() => _step = _RegisterStep.setPrice),
        ),
      );
    }

    return ResaleBottomBar(
      child: ResaleActionButton(
        label: ResaleStrings.registerSubmit,
        onPressed: _price.canSubmit && !_submitting ? _submit : null,
      ),
    );
  }
}
