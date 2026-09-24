import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../core/widgets/poster_stage.dart';
import '../../../routes/app_routes.dart';
import '../../alarm/constants.dart';
import '../../alarm/models/alarm_status.dart';
import '../../alarm/state/alarm_api_scope.dart';
import '../../auth/state/auth_session_scope.dart';
import '../../booking/models/performance.dart';
import '../../booking/state/booking_scope.dart';
import '../../favorite/state/favorite_scope.dart';
import '../../favorite/utils/toggle_favorite_show.dart';
import '../constants.dart';
import '../data/show_api.dart';
import '../models/show_detail.dart';
import '../state/show_api_scope.dart';
import '../utils/favorite_target.dart';
import '../widgets/show_artist_list.dart';
import '../widgets/show_detail_app_bar.dart';
import '../widgets/show_detail_bottom_bar.dart';
import '../widgets/show_detail_skeleton.dart';
import '../widgets/show_detail_summary.dart';
import '../widgets/show_notice.dart';
import '../widgets/zone_price_card.dart';

/// 공연 상세. 홈에서 들어오는 유일한 화면이고, 예매 흐름 진입도 여기서만 일어난다.
/// 공연 번호를 받아 화면이 직접 조회하고, 기다리는 동안과 실패는 [AsyncBoundary] 가 맡는다.
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

  /// 다시 불러온다. 실패 화면의 '다시 시도' 가 쓴다. 당겨서 새로 고침 같은 자동
  /// 재조회는 두지 않는다 — 서버가 상세 조회마다 조회수를 1 올린다.
  void _reload() {
    final next = _fetch();
    setState(() {
      _detail = next;
    });
  }

  /// 공연 찜은 서버에 남는다. 로그인 안내와 실패 알림은 공통 동작이 맡는다.
  Future<void> _toggleFavorite(ShowDetail detail) =>
      toggleFavoriteShow(context, detail.toFavorite());

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
        loading: const ShowDetailSkeleton(),
        builder: (context, detail) =>
            _LoadedShow(detail: detail, clock: widget.clock),
      ),
    );
  }
}

/// 공연을 받아 온 뒤의 화면. 본문과 하단 바를 함께 그린다. 하단 바를 여기 두는 것은
/// 공연을 받아야 무엇을 그릴지 정해져서다 — Scaffold 자리에서 하면 로딩·실패 분기가 갈라진다.
class _LoadedShow extends StatefulWidget {
  const _LoadedShow({required this.detail, required this.clock});

  final ShowDetail detail;
  final DateTime Function() clock;

  @override
  State<_LoadedShow> createState() => _LoadedShowState();
}

class _LoadedShowState extends State<_LoadedShow> {
  /// 지금 시각. 오픈 시각을 넘기는 순간 상태 뱃지와 하단 바가 함께 바뀌어야 해서 화면이 든다.
  /// `setState` 가 아니라 [ValueNotifier] 인 것은 1초마다 화면 전체가 재빌드되지 않게
  /// 시간에 기대는 두 곳만 구독하려는 것이다.
  late final ValueNotifier<DateTime> _now = ValueNotifier(widget.clock());

  Timer? _tick;

  /// 하단 바. 안내 스낵바를 그 위로 띄우려고 높이를 잰다.
  final GlobalKey _bottomBarKey = GlobalKey();

  /// 이 공연에 대한 내 알림 신청 상태. 버튼 두 개가 이것으로 켜짐과 꺼짐을 그린다.
  /// 상세 응답에는 이 값이 없어 따로 묻고, 로그아웃 상태면 묻지 않고 둘 다 꺼진 채로 둔다.
  AlarmStatus _alarms = AlarmStatus.none;

  /// 신청 상태를 어느 로그인 상태에서 물었는가. 로그인 상태가 바뀔 때만 다시
  /// 묻거나 비우려고 둔다. 처음에는 아무 상태에서도 묻지 않았으므로 null.
  bool? _alarmsLoggedIn;

  /// 신청 상태를 받기 전에 버튼을 눌렀는가. 그랬다면 늦게 도착한 응답이 방금
  /// 누른 결과를 덮지 않게 버린다.
  bool _alarmsTouched = false;

  /// 서버에 보내는 중인 알림 종류. 끝나기 전에 같은 버튼을 또 누르면 무시한다 —
  /// 켜기와 끄기가 겹쳐 나가면 어느 쪽이 나중에 도착할지 알 수 없다.
  final Set<AlarmType> _sendingAlarms = {};

  @override
  void initState() {
    super.initState();
    _startTickingIfUpcoming();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loggedIn = AuthSessionScope.maybeOf(context)?.isLoggedIn ?? false;
    if (loggedIn == _alarmsLoggedIn) return;
    _alarmsLoggedIn = loggedIn;
    _alarmsTouched = false;
    if (loggedIn) {
      _loadAlarms();
    } else {
      // 로그아웃하면 직전 회원의 신청 상태가 남지 않게 지운다.
      _alarms = AlarmStatus.none;
    }
  }

  /// 신청 상태를 서버에 묻는다. 못 받아도 알리지 않는다 — 버튼이 꺼진 채로
  /// 보일 뿐이고, 눌러서 신청하는 데는 지장이 없다.
  Future<void> _loadAlarms() async {
    final api = AlarmApiScope.maybeOf(context);
    if (api == null) return;
    try {
      final status = await api.fetchStatus(widget.detail.id);
      // 기다리는 사이 버튼을 눌렀거나 로그아웃했으면 이 응답은 낡았다.
      if (!mounted || _alarmsTouched || _alarmsLoggedIn != true) return;
      setState(() => _alarms = status);
    } on ApiException {
      // 위 설명대로 알리지 않는다.
    }
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

  /// 알림 버튼을 눌렀을 때. 버튼부터 바꾸고 서버에 보낸다. 로그아웃 상태면 부르지 않고
  /// 안내만 한다(서버가 401 을 준다). 실패하면 버튼을 되돌리고 서버가 준 문구로 알린다.
  /// 신청했다는 안내는 서버가 받은 뒤에 띄운다 — 먼저 띄우면 실패 안내와 연달아 뜬다.
  Future<void> _toggleAlarm(AlarmType type) async {
    if (!(AuthSessionScope.maybeRead(context)?.isLoggedIn ?? false)) {
      showInfoSnackBar(
        context,
        ShowDetailStrings.alarmLoginRequired,
        bottomMargin: _snackBarBottomMargin,
      );
      return;
    }
    final api = AlarmApiScope.maybeOf(context);
    if (api == null || _sendingAlarms.contains(type)) return;

    final on = !_alarms.isOn(type);
    _alarmsTouched = true;
    setState(() {
      _alarms = _alarms.copyWith(type, on: on);
      _sendingAlarms.add(type);
    });

    final concertId = widget.detail.id;
    try {
      if (on) {
        await api.subscribe(concertId, type);
      } else {
        await api.unsubscribe(concertId, type);
      }
      if (mounted) _notify(_alarmMessage(type, on: on));
    } catch (e) {
      if (!mounted) return;
      setState(() => _alarms = _alarms.copyWith(type, on: !on));
      showErrorSnackBar(
        context,
        e is ApiException ? e.message : AlarmStrings.toggleFailed,
        bottomMargin: _snackBarBottomMargin,
      );
    } finally {
      if (mounted) setState(() => _sendingAlarms.remove(type));
    }
  }

  static String _alarmMessage(AlarmType type, {required bool on}) =>
      switch (type) {
        AlarmType.concertOpen =>
          on ? ShowDetailStrings.openAlarmOn : ShowDetailStrings.openAlarmOff,
        AlarmType.marketListing =>
          on
              ? ShowDetailStrings.marketAlarmOn
              : ShowDetailStrings.marketAlarmOff,
      };

  /// 알림 신청 결과를 한 줄로 알린다. 떠 있던 안내는 공통 동작이 걷어내므로, 켜고 바로
  /// 꺼도 먼저 뜬 '신청했어요' 가 남지 않는다.
  void _notify(String message) {
    showSuccessSnackBar(context, message, bottomMargin: _snackBarBottomMargin);
  }

  /// 안내 스낵바를 띄울 높이. 바 높이가 상태마다 달라(예매 중은 버튼 둘, 오픈 전은
  /// 남은 시간 한 줄 추가) 숫자로 적지 않고 하단 바를 재서 정한다.
  /// 아직 재지 못했으면 null 을 돌려 스낵바 쪽 기본 여백에 맡긴다.
  double? get _snackBarBottomMargin {
    final box = _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.size.height + ShowDetailMetrics.snackBarGap;
  }

  /// 예매를 시작한다. 로그인부터 확인한다 — 서버는 좌석을 **잡을 때** 요청자를
  /// 요구하므로 로그인 없이도 배치도까지는 그려지는데, 그대로 두면 자리를 다 고른
  /// 뒤에야 로그인하라는 말을 듣게 된다. 로그인 화면은 성공하면 홈으로 가며 이
  /// 화면까지 걷어내므로 여기서 예매를 이어 갈 일은 없다.
  Future<void> _startBooking() async {
    if (!AuthSessionScope.of(context).isLoggedIn) {
      Navigator.pushNamed(context, AppRoutes.login);
      return;
    }
    // 예매 화면들의 머리말에 찍을 공연을 여기서 넘긴다. 저쪽이 공연 번호로
    // 다시 조회하게 하면 같은 공연을 두 번 부르고, 서버 조회수도 두 번 오른다.
    BookingScope.read(context).startBooking(
      widget.detail.id,
      performance: Performance(
        title: widget.detail.title,
        venue: widget.detail.venue,
        startAt: widget.detail.startAt,
        posterUrl: widget.detail.posterUrl,
      ),
    );
    // 구역 화면이 뜨자마자 그 위에 보안문자를 띄운다. 대기열이 붙으면 그 앞이다.
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
                child: PosterStage(
                  url: detail.posterUrl,
                  verticalInset: ShowDetailMetrics.posterVerticalInset,
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
                        phase: detail.phaseAt(now),
                      ),
                    ),
                    // 가격이 비어 오면 빈 카드를 세우는 대신 자리를 접는다.
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
                    // 안내 이미지가 없어도 자리를 접지 않는다. 예매 마감·양도·환불은 공연과
                    // 무관하게 늘 같은 규칙이라 ShowNotice 가 공통 규정을 대신 적는다.
                    const SizedBox(height: ShowDetailMetrics.sectionGap),
                    _Section(
                      title: ShowDetailStrings.noticeSection,
                      child: ShowNotice(imageUrls: detail.imageUrls),
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
            key: _bottomBarKey,
            detail: detail,
            now: now,
            // 상단 하트(찜)와는 별개다. 찜을 풀어도 알림 신청은 그대로다.
            isOpenAlarmOn: _alarms.concertOpen,
            isMarketAlarmOn: _alarms.marketListing,
            onBookPressed: _startBooking,
            onOpenAlarmPressed: () => _toggleAlarm(AlarmType.concertOpen),
            onMarketAlarmPressed: () => _toggleAlarm(AlarmType.marketListing),
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
