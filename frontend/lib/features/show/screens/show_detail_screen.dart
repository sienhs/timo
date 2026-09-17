import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/poster_image.dart';
import '../../../routes/app_routes.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../booking/constants.dart';
import '../../booking/models/performance.dart';
import '../../booking/state/booking_scope.dart';
import '../../favorite/state/favorite_scope.dart';
import '../constants.dart';
import '../data/show_api.dart';
import '../models/show_detail.dart';
import '../state/show_api_scope.dart';
import '../utils/favorite_target.dart';
import '../widgets/show_artist_list.dart';
import '../widgets/show_detail_app_bar.dart';
import '../widgets/show_detail_bottom_bar.dart';
import '../widgets/show_detail_summary.dart';
import '../widgets/show_notice.dart';
import '../widgets/zone_price_card.dart';

/// 공연 상세. 홈에서 들어오는 유일한 화면이고, 예매 흐름 진입도 여기서만
/// 일어난다.
///
/// 공연 번호를 받아 **화면이 직접** 조회한다. 기다리는 동안과 실패는
/// [AsyncBoundary] 가 맡는다. 라우트가 미리 받아 넘겨주던 방식은 목업이라
/// 가능했던 것이고, 서버에 물으려면 기다리는 상태가 화면 안에 있어야 한다.
class ShowDetailScreen extends StatefulWidget {
  const ShowDetailScreen({
    super.key,
    required this.showId,
    this.clock = DateTime.now,
  });

  /// 서버가 준 공연 번호. 홈·검색이 누른 공연의 번호를 그대로 넘긴다.
  final int showId;

  /// 지금 시각을 읽는 함수. 테스트에서 시간을 흐르게 하려고 받는다
  /// (홈의 오픈 뱃지가 `now` 를 받는 것과 같은 이유다).
  final DateTime Function() clock;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  late final ShowApi _api = ShowApiScope.of(context);
  late Future<ShowDetail> _detail = _fetch();

  /// 받아 온 공연. 상단 바의 하트가 쓴다 — 본문은 [AsyncBoundary] 가 받아
  /// 주지만 하트는 그 바깥(Scaffold 의 appBar)에 있어 따로 들고 있어야 한다.
  /// 아직 못 받았으면 null 이고 하트는 눌리지 않는다.
  ShowDetail? _loaded;

  Future<ShowDetail> _fetch() {
    final future = _api.fetchShowDetail(widget.showId);
    // 실패는 본문의 AsyncBoundary 가 알린다. 여기서는 삼켜서 처리되지 않은
    // 오류로 새지 않게만 한다.
    future.then<void>((detail) {
      if (mounted) setState(() => _loaded = detail);
    }, onError: (Object _) {});
    return future;
  }

  /// 다시 불러온다. 실패 화면의 '다시 시도' 가 쓴다.
  ///
  /// 스스로 다시 부르는 길(당겨서 새로 고침, 주기적 갱신)은 두지 않았다.
  /// 서버가 상세 조회마다 조회수를 1 올리기 때문이다.
  void _reload() {
    final next = _fetch();
    setState(() {
      _detail = next;
    });
  }

  void _toggleFavorite(ShowDetail detail) {
    FavoriteScope.read(context).toggleShow(detail.toFavorite());
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _loaded;
    return Scaffold(
      appBar: ShowDetailAppBar(
        isFavorite: FavoriteScope.of(context).favorites.hasShow(widget.showId),
        onFavoritePressed: loaded == null
            ? null
            : () => _toggleFavorite(loaded),
      ),
      body: AsyncBoundary<ShowDetail>(
        future: _detail,
        onRetry: _reload,
        builder: (context, detail) =>
            _LoadedShow(detail: detail, clock: widget.clock, onNotify: _notify),
      ),
    );
  }
}

/// 공연을 받아 온 뒤의 화면. 본문과 하단 바를 함께 그린다.
///
/// 하단 바를 `Scaffold.bottomNavigationBar` 가 아니라 여기에 두는 이유:
/// 공연을 받아야 무엇을 그릴지 정해지는데, 그 판단을 Scaffold 자리에서 하면
/// 로딩·실패 분기가 본문과 하단 바 두 곳으로 갈라진다.
class _LoadedShow extends StatefulWidget {
  const _LoadedShow({
    required this.detail,
    required this.clock,
    required this.onNotify,
  });

  final ShowDetail detail;
  final DateTime Function() clock;
  final void Function(String message) onNotify;

  @override
  State<_LoadedShow> createState() => _LoadedShowState();
}

class _LoadedShowState extends State<_LoadedShow> {
  /// 지금 시각. 오픈 시각을 넘기는 순간 화면을 다시 열지 않아도 상태 뱃지와
  /// 하단 바가 함께 바뀌어야 해서 화면이 들고 있는다.
  ///
  /// `setState` 가 아니라 [ValueNotifier] 인 이유: 1초마다 화면 전체를 다시
  /// 그리면 포스터·안내문까지 매초 재빌드된다. 시간에 기대는 두 곳만
  /// 구독한다.
  late final ValueNotifier<DateTime> _now = ValueNotifier(widget.clock());

  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _startTickingIfUpcoming();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _now.dispose();
    super.dispose();
  }

  /// 이미 오픈한 공연은 시간을 잴 이유가 없다. 오픈 시각을 넘기면 타이머를
  /// 스스로 멈춘다.
  void _startTickingIfUpcoming() {
    if (widget.detail.isOpenAt(_now.value)) return;
    _tick = Timer.periodic(ShowDetailMetrics.countdownTick, (timer) {
      final now = widget.clock();
      _now.value = now;
      if (widget.detail.isOpenAt(now)) timer.cancel();
    });
  }

  /// 예매를 시작한다. 로그인부터 확인한다.
  ///
  /// 좌석을 다 고르고 결제 직전에 막는 것보다 들어가기 전에 막는 편이 낫다.
  /// 서버는 좌석을 **잡을 때** 요청자를 요구하므로 로그인 없이도 배치도까지는
  /// 그려진다. 그대로 두면 자리를 고르고 확인 다이얼로그까지 누른 뒤에야
  /// 로그인하라는 말을 듣게 된다.
  ///
  /// 로그인 화면은 성공하면 결과로 true 를 넘기며 닫힌다. 돌아오면 고르던
  /// 공연 그대로 예매를 이어 간다.
  Future<void> _startBooking() async {
    if (!AuthSessionScope.of(context).isLoggedIn) {
      final loggedIn = await Navigator.pushNamed(context, AppRoutes.login);
      if (loggedIn != true || !mounted) return;
    }
    if (!mounted) return;
    // 예매 화면들의 머리말에 찍을 공연을 여기서 넘긴다. 저쪽이 공연 번호로
    // 다시 조회하게 하면 같은 공연을 두 번 부르고, 서버 조회수도 두 번 오른다.
    BookingScope.read(context).startBooking(
      widget.detail.id,
      performance: Performance(
        title: widget.detail.title,
        venue: widget.detail.venue,
        startAt: widget.detail.startAt,
        posterUrl: widget.detail.posterUrl,
        bookingFee: BookingConstants.bookingFee,
      ),
    );
    await Navigator.pushNamed(
      context,
      AppRoutes.zoneSelection,
      arguments: widget.detail.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(
              bottom: ShowDetailMetrics.contentBottomGap,
            ),
            children: [
              AspectRatio(
                aspectRatio: ShowDetailMetrics.posterAspectRatio,
                child: PosterImage.network(
                  url: detail.posterUrl,
                  decodeWidth: MediaQuery.sizeOf(context).width,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ShowDetailMetrics.horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: ShowDetailMetrics.summaryTopGap),
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _now,
                      builder: (context, now, _) => ShowDetailSummary(
                        detail: detail,
                        isOpen: detail.isOpenAt(now),
                      ),
                    ),
                    // 가격은 구역 목록에서 따로 받아 오는데, 그 조회는 로그인해야
                    // 열린다. 못 받았으면 빈 카드를 세우는 대신 자리를 접는다.
                    if (detail.zonePrices.isNotEmpty) ...[
                      const SizedBox(height: ShowDetailMetrics.sectionGap),
                      _Section(
                        title: ShowDetailStrings.zonePriceSection,
                        child: ZonePriceCard(zonePrices: detail.zonePrices),
                      ),
                    ],
                    const SizedBox(height: ShowDetailMetrics.sectionGap),
                    _Section(
                      title: ShowDetailStrings.artistSection,
                      child: ShowArtistList(artists: detail.artists),
                    ),
                    const SizedBox(height: ShowDetailMetrics.sectionGap),
                    const _Section(
                      title: ShowDetailStrings.noticeSection,
                      child: ShowNotice(paragraphs: ShowDetailStrings.notice),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<DateTime>(
          valueListenable: _now,
          builder: (context, now, _) => ShowDetailBottomBar(
            detail: detail,
            now: now,
            onBookPressed: _startBooking,
            onNotifyPressed: () =>
                widget.onNotify(ShowDetailStrings.notifyNotReady),
          ),
        ),
      ],
    );
  }
}

/// 제목 한 줄 + 내용. 상세의 세 섹션이 같은 간격으로 붙게 한다.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: ShowDetailMetrics.sectionTitleGap),
        child,
      ],
    );
  }
}
