import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/async_boundary.dart';
import '../../../core/widgets/error_snack_bar.dart';
import '../../../core/widgets/poster_stage.dart';
import '../../../routes/app_routes.dart';
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
        builder: (context, detail) =>
            _LoadedShow(detail: detail, clock: widget.clock),
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
  const _LoadedShow({required this.detail, required this.clock});

  final ShowDetail detail;
  final DateTime Function() clock;

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

  /// 하단 바. 안내 스낵바를 그 위로 띄우려고 높이를 잰다.
  final GlobalKey _bottomBarKey = GlobalKey();

  /// 예매 오픈 알림을 신청했는가.
  ///
  /// **아직 화면 안에서만 켜지고 꺼진다.** 서버에 알림 신청 API 가 이미 있지만
  /// (`AlarmController` — `PUT/DELETE /api/v1/alarms/{concertId}/{type}`,
  /// 상태는 `GET /api/v1/alarms/{concertId}`) 붙이는 일은 다른 사람 몫이라
  /// 여기서는 버튼이 갈리는 모양까지만 만들어 둔다. 붙일 때는 이 두 필드를
  /// 서버에서 받은 값으로 바꾸고 아래 두 함수 안에서 요청을 보내면 된다 —
  /// 화면 트리와 버튼 쪽은 그대로 둘 수 있다.
  bool _openAlarmOn = false;

  /// 양도 매물 알림을 신청했는가. 오픈 알림과 따로 켜고 끈다.
  bool _marketAlarmOn = false;

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

  /// 오픈 알림 버튼을 눌렀을 때.
  void _toggleOpenAlarm() {
    setState(() => _openAlarmOn = !_openAlarmOn);
    _notify(
      _openAlarmOn
          ? ShowDetailStrings.openAlarmOn
          : ShowDetailStrings.openAlarmOff,
    );
  }

  /// 양도 마켓 알림 버튼을 눌렀을 때.
  void _toggleMarketAlarm() {
    setState(() => _marketAlarmOn = !_marketAlarmOn);
    _notify(
      _marketAlarmOn
          ? ShowDetailStrings.marketAlarmOn
          : ShowDetailStrings.marketAlarmOff,
    );
  }

  /// 알림 신청 결과를 한 줄로 알린다. 앱 공통 안내 상자를 쓴다.
  ///
  /// 띄우기 전에 떠 있던 것을 걷어낸다(공통 동작이 맡는다). 켜고 바로 끄면
  /// 먼저 뜬 '신청했어요' 가 다 사라질 때까지 줄을 서서, 방금 끈 사람 눈앞에
  /// 신청했다는 말이 남는다.
  ///
  /// 아래 여백은 기본값을 쓴다. 하단 바를 `Scaffold.bottomNavigationBar` 가
  /// 아니라 본문 안에 그려서 Flutter 가 스낵바를 올려 주지 않기 때문이다.
  void _notify(String message) {
    showSuccessSnackBar(context, message, bottomMargin: _snackBarBottomMargin);
  }

  /// 안내 스낵바를 띄울 높이. 하단 바를 **재서** 정한다.
  ///
  /// 숫자로 적어 두지 않는 이유는 바 높이가 상태마다 다르기 때문이다 — 예매
  /// 중에는 버튼이 둘이고, 오픈 전에는 버튼 위에 남은 시간 한 줄이 더 붙는다.
  /// 한 값으로 적으면 어느 한 상태에서는 안내가 버튼을 덮는다.
  ///
  /// 아직 재지 못했으면 기본 여백(스낵바 쪽 기본값)에 맡긴다.
  double? get _snackBarBottomMargin {
    final box = _bottomBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.size.height + ShowDetailMetrics.snackBarGap;
  }

  /// 예매를 시작한다. 로그인부터 확인한다.
  ///
  /// 좌석을 다 고르고 결제 직전에 막는 것보다 들어가기 전에 막는 편이 낫다.
  /// 서버는 좌석을 **잡을 때** 요청자를 요구하므로 로그인 없이도 배치도까지는
  /// 그려진다. 그대로 두면 자리를 고르고 확인 다이얼로그까지 누른 뒤에야
  /// 로그인하라는 말을 듣게 된다.
  ///
  /// 로그인 화면은 성공하면 홈으로 가며 이 화면까지 걷어낸다. 그래서 여기서
  /// 예매를 이어 갈 일은 없고, 로그인 화면으로 보내는 데서 끝난다.
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
                    // 안내 이미지가 없어도 자리를 접지 않는다. 이미지가
                    // 없으면 ShowNotice 가 공통 규정을 대신 적는다 - 예매
                    // 마감·양도·환불은 공연과 무관하게 늘 같은 규칙이라,
                    // 주최사가 이미지를 안 올렸다고 안 보여 줄 이유가 없다.
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
            isOpenAlarmOn: _openAlarmOn,
            isMarketAlarmOn: _marketAlarmOn,
            onBookPressed: _startBooking,
            onOpenAlarmPressed: _toggleOpenAlarm,
            onMarketAlarmPressed: _toggleMarketAlarm,
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
