import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_search_field.dart';
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
import '../widgets/market_hours_countdown.dart';
import '../widgets/resale_app_bar.dart';
import '../widgets/resale_list_skeleton.dart';
import '../widgets/resale_bottom_bar.dart';
import '../widgets/resale_empty_view.dart';
import '../widgets/sort_tab_row.dart';

/// 양도마켓 첫 화면. 매물이 올라온 공연을 고른다. 들어오면 먼저 서버에 운영
/// 상태를 묻고([MarketHours]) 닫혀 있으면 목록 대신 다음 오픈까지 남은 시간을
/// 보여 준다([MarketClosedView]). 등록은 닫혀 있어도 되므로 아래 버튼은 늘 살아
/// 있다. 검색·정렬은 한 번에 다 받은 목록([ResaleMetrics.pageSize])을 앱에서 세운다.
class MarketConcertsScreen extends StatefulWidget {
  const MarketConcertsScreen({super.key, this.clock = DateTime.now});

  /// 기기 시각을 읽는 함수. 테스트에서 시각을 고정하려고 받는다.
  final DateTime Function() clock;

  @override
  State<MarketConcertsScreen> createState() => _MarketConcertsScreenState();
}

class _MarketConcertsScreenState extends State<MarketConcertsScreen> {
  /// 진행 중인 운영 상태 조회. 비로그인이면 null 이다 — 마켓은 조회까지
  /// 인증을 요구해 비로그인으로 부르면 401 만 받는다.
  Future<MarketHours>? _hours;

  /// 받아 둔 운영 상태. 상단 바의 카운트다운과 아래 버튼이 [AsyncBoundary]
  /// 밖에 있어 여기에도 한 벌 든다.
  MarketHours? _loadedHours;

  /// 진행 중인 목록 조회. 열려 있을 때만 있다.
  Future<List<MarketConcert>>? _concerts;

  final _searchController = TextEditingController();
  String _query = '';
  ConcertSort _sort = ConcertSort.popular;

  bool get _isLoggedIn =>
      AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 로그인한 채로 들어왔거나 로그인하고 돌아왔을 때 받아 온다. 로그아웃되면
    // 들고 있던 것을 버려 본문이 로그인 안내로 바뀐다.
    if (_isLoggedIn) {
      _hours ??= _loadHours();
    } else {
      _hours = null;
      _loadedHours = null;
      _concerts = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 운영 상태를 받고, 열려 있으면 이어서 목록을 요청한다. 여기서 거는 이유는
  /// 빌드 중에 상태를 바꾸지 않기 위해서다.
  Future<MarketHours> _loadHours() async {
    final api = ResaleApiScope.of(context);
    final hours = await api.fetchMarketHours();
    if (mounted) {
      setState(() {
        _loadedHours = hours;
        _concerts = hours.isOpen ? api.fetchConcerts() : null;
      });
    }
    return hours;
  }

  /// 처음부터 다시. 다시 시도, 마켓 경계 시각, 등록하고 돌아온 뒤가 모두 이걸
  /// 부른다 — 어느 쪽이든 서버에 다시 묻는 게 맞다.
  void _reload() {
    setState(() {
      _loadedHours = null;
      _concerts = null;
      _hours = _isLoggedIn ? _loadHours() : null;
    });
  }

  /// 양도 등록으로 간다. 등록하고 돌아왔으면 매물 수가 바뀌었으니 다시 받는다.
  /// 결과 타입을 `pushNamed<bool>` 로 못 박지 않는다 — 라우트 등록부가 만드는
  /// 라우트는 `Route<dynamic>` 이라 실기기에서 캐스팅 예외가 난다.
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
    final hours = _loadedHours;

    return Scaffold(
      backgroundColor: AppColors.surface,
      // 상단 바에 남은 시간을 적지 않는다. 닫혀 있을 때의 카운트다운은 본문
      // 한가운데가 맡는다.
      appBar: ResaleAppBar(title: ResaleStrings.marketTitle),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 세는 일만 남긴다. 그리지는 않는다([Offstage]) — 마감 시각이 되면
            // 본문이 닫힘 안내로 바뀌어야 하고, 그 신호가 이 카운트다운이다.
            if (hours != null && hours.isOpen)
              Offstage(
                child: MarketHoursCountdown(
                  hours: hours,
                  clock: widget.clock,
                  onElapsed: _reload,
                  semanticsLabel: ResaleStrings.openRemainingSemantics,
                ),
              ),
            Expanded(child: _body()),
            // 로그인 전에는 줄 자체를 내지 않는다. 눌리지 않는 버튼은 자리만
            // 차지하고, 로그인하라는 말은 본문이 이미 하고 있다.
            if (_isLoggedIn)
              ResaleBottomBar(
                child: ResaleActionButton(
                  label: ResaleStrings.registerAction,
                  onPressed: _openRegister,
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
        showMascot: false,
        actionLabel: AuthStrings.login,
        onAction: () => Navigator.pushNamed(context, AppRoutes.login),
      );
    }

    return AsyncBoundary<MarketHours>(
      future: _hours!,
      onRetry: _reload,
      builder: (context, hours) {
        if (!hours.isOpen) {
          return MarketClosedView(
            hours: hours,
            clock: widget.clock,
            onOpened: _reload,
          );
        }
        return _openBody();
      },
    );
  }

  /// 열려 있을 때의 본문. 검색 칸·정렬 탭·공연 목록.
  Widget _openBody() {
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
              AppSearchField(
                controller: _searchController,
                hintText: ResaleStrings.searchHint,
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
            loading: const ResaleListSkeleton(),
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
