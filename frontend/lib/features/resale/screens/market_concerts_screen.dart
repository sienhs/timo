import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../routes/app_routes.dart';
import '../../auth/constants.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/market_concert.dart';
import '../models/market_hours.dart';
import '../models/market_sort.dart';
import '../state/resale_api_scope.dart';
import '../widgets/market_closed_view.dart';
import '../widgets/market_concert_card.dart';
import '../widgets/market_countdown.dart';
import '../widgets/resale_app_bar.dart';
import '../widgets/resale_bottom_bar.dart';
import '../widgets/resale_empty_view.dart';
import '../widgets/resale_search_field.dart';
import '../widgets/sort_tab_row.dart';

/// 양도마켓 첫 화면. 매물이 올라온 공연을 고른다.
///
/// 마켓이 닫혀 있으면 목록 대신 다음 오픈까지 남은 시간을 보여 준다
/// ([MarketClosedView]). 살 수 없는 매물을 늘어놓으면 눌러 보고서야 닫힌 것을
/// 알게 되기 때문이다. **등록은 닫혀 있어도 되므로** 아래 버튼은 그대로 둔다.
///
/// 목록을 거르고 다시 세우는 일은 모두 앱에서 한다. 한 번에 다 받으므로
/// ([ResaleMetrics.pageSize]) 글자마다 서버에 다녀올 이유가 없다.
class MarketConcertsScreen extends StatefulWidget {
  const MarketConcertsScreen({super.key, this.clock = DateTime.now});

  /// 지금 시각을 읽는 함수. 마켓 운영 시간 판정이 이 값을 본다.
  ///
  /// 테스트에서 시각을 고정하려고 받는다(내 티켓 화면과 같은 방식이다). 닫힌
  /// 화면은 하루 중 정해진 때에만 나오므로, 이 인자가 없으면 눈으로 확인할
  /// 방법이 코드를 고쳤다 되돌리는 것뿐이다.
  final DateTime Function() clock;

  @override
  State<MarketConcertsScreen> createState() => _MarketConcertsScreenState();
}

class _MarketConcertsScreenState extends State<MarketConcertsScreen> {
  /// 진행 중인 조회. 비로그인이거나 마켓이 닫혀 있으면 null 이다 — 부를
  /// 이유가 없고, 비로그인으로 부르면 401 만 받는다.
  Future<List<MarketConcert>>? _concerts;

  final _searchController = TextEditingController();
  String _query = '';
  ConcertSort _sort = ConcertSort.popular;

  late MarketHours _hours = MarketHours.at(widget.clock());

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  /// 지금 목록을 받아 올 수 있는 상태인가.
  bool get _canLoad => _isLoggedIn && _hours.isOpen;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인한 채로 들어왔거나 이 화면에서 로그인하고 돌아왔을 때 받아 온다.
    // 로그아웃되면 들고 있던 목록을 버린다 — 그러면 본문이 로그인 안내로
    // 바뀐다(충전·내 티켓 화면과 같은 방식).
    if (_canLoad) {
      _concerts ??= ResaleApiScope.of(context).fetchConcerts();
    } else {
      _concerts = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _concerts = _canLoad ? ResaleApiScope.of(context).fetchConcerts() : null;
    });
  }

  /// 마켓이 열리거나 닫히는 순간. 다시 판정해 본문을 바꾼다.
  void _refreshHours() {
    setState(() => _hours = MarketHours.at(widget.clock()));
    _reload();
  }

  /// 양도 등록으로 간다. 등록하고 돌아왔으면 목록을 다시 받는다 — 방금 올린
  /// 매물이 공연 목록의 매물 수에 반영돼야 한다.
  ///
  /// 결과 타입을 `pushNamed<bool>` 로 못 박지 않는다. 라우트 등록부가 만드는
  /// 라우트는 `Route<dynamic>` 이라 타입을 지정하면 실기기에서 캐스팅 예외로
  /// 눌러도 아무 일이 안 일어난다(위젯 테스트는 이 경계를 안 탄다).
  Future<void> _openRegister() async {
    final registered = await Navigator.pushNamed(
      context,
      AppRoutes.resaleRegister,
    );
    if (registered == true && mounted) _reload();
  }

  void _openListings(MarketConcert concert) {
    Navigator.pushNamed(context, AppRoutes.resaleListings, arguments: concert);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: ResaleAppBar(
        title: ResaleStrings.marketTitle,
        // 남은 시간은 열려 있을 때만 뜻이 있다. 닫혀 있을 때의 카운트다운은
        // 본문 한가운데가 맡는다.
        trailing: _hours.isOpen
            ? MarketCountdown(
                until: _hours.nextBoundary,
                clock: widget.clock,
                onElapsed: _refreshHours,
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
            Expanded(child: _body()),
            ResaleBottomBar(
              // 닫혀 있을 때만 붙는 한 줄. 버튼이 왜 아직 살아 있는지 알린다.
              notice: _hours.isOpen ? null : ResaleStrings.closedRegisterNotice,
              child: ResaleActionButton(
                label: ResaleStrings.registerAction,
                onPressed: _isLoggedIn ? _openRegister : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (!_isLoggedIn) {
      return ResaleEmptyView(
        message: ResaleStrings.loginPrompt,
        actionLabel: AuthStrings.login,
        onAction: () => Navigator.pushNamed(context, AppRoutes.login),
      );
    }
    if (!_hours.isOpen) {
      return MarketClosedView(
        hours: _hours,
        clock: widget.clock,
        onOpened: _refreshHours,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ResaleMetrics.horizontalPadding,
            8,
            ResaleMetrics.horizontalPadding,
            0,
          ),
          child: Column(
            children: [
              ResaleSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
              SortTabRow(
                labels: [for (final sort in ConcertSort.values) sort.label],
                selectedIndex: ConcertSort.values.indexOf(_sort),
                onSelected: (index) =>
                    setState(() => _sort = ConcertSort.values[index]),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBoundary<List<MarketConcert>>(
            future: _concerts!,
            onRetry: _reload,
            builder: (context, concerts) => _list(concerts),
          ),
        ),
      ],
    );
  }

  Widget _list(List<MarketConcert> concerts) {
    final matched = _sort.sorted(
      concerts
          .where((concert) => concert.title.contains(_query.trim()))
          .toList(),
    );

    if (matched.isEmpty) {
      return ResaleEmptyView(
        message: _query.trim().isEmpty
            ? ResaleStrings.emptyConcerts
            : ResaleStrings.searchEmpty(_query.trim()),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        ResaleMetrics.horizontalPadding,
        8,
        ResaleMetrics.horizontalPadding,
        8,
      ),
      itemCount: matched.length,
      itemBuilder: (context, index) => MarketConcertCard(
        concert: matched[index],
        onTap: () => _openListings(matched[index]),
      ),
    );
  }
}
