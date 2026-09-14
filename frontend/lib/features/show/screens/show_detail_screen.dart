import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/poster_image.dart';
import '../../../routes/app_routes.dart';
import '../../auth/state/auth_session_scope.dart';
import '../constants.dart';
import '../models/show_detail.dart';
import '../widgets/seat_price_card.dart';
import '../widgets/show_artist_list.dart';
import '../widgets/show_detail_app_bar.dart';
import '../widgets/show_detail_bottom_bar.dart';
import '../widgets/show_detail_summary.dart';
import '../widgets/show_notice.dart';

/// 공연 상세. 홈에서 들어오는 유일한 화면이고, 예매 흐름 진입도 여기서만
/// 일어난다.
///
/// 공연 id 가 아니라 [ShowDetail] 을 받는다. 조회는 라우트가 하고 화면은
/// 그리기만 한다 — 이렇게 두면 화면을 단독으로 띄워 상태별로 확인할 수 있다
/// (`AppRoutes` 의 다른 화면들과 같은 방식이다).
class ShowDetailScreen extends StatefulWidget {
  const ShowDetailScreen({
    super.key,
    required this.detail,
    this.concertId,
    this.clock = DateTime.now,
  });

  final ShowDetail detail;

  /// 서버가 준 공연 번호. 예매 흐름이 좌석을 물을 때 이 번호를 함께 보낸다.
  ///
  /// [detail] 과 따로 받는 이유: 상세 조회가 아직 목업이라 화면에 그려지는
  /// 공연과 서버가 아는 공연이 다르다. 그래도 **홈에서 누른 공연의 진짜 번호**
  /// 는 라우트 인자로 여기까지 와 있어서, 좌석만은 맞는 공연으로 물을 수 있다.
  /// 공연 상세 API 연동(S15P21D206-175)이 붙으면 [detail] 안으로 합친다.
  final int? concertId;

  /// 지금 시각을 읽는 함수. 테스트에서 시간을 흐르게 하려고 받는다
  /// (홈의 오픈 뱃지가 `now` 를 받는 것과 같은 이유다).
  final DateTime Function() clock;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
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

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;

    return Scaffold(
      appBar: ShowDetailAppBar(
        onFavoritePressed: () => _notify(ShowDetailStrings.favoriteNotReady),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          bottom: ShowDetailMetrics.contentBottomGap,
        ),
        children: [
          AspectRatio(
            aspectRatio: ShowDetailMetrics.posterAspectRatio,
            child: PosterImage.asset(
              assetPath: detail.posterAsset,
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
                const SizedBox(height: ShowDetailMetrics.sectionGap),
                _Section(
                  title: ShowDetailStrings.seatPriceSection,
                  child: SeatPriceCard(seatPrices: detail.seatPrices),
                ),
                const SizedBox(height: ShowDetailMetrics.sectionGap),
                _Section(
                  title: ShowDetailStrings.artistSection,
                  child: ShowArtistList(artists: detail.artists),
                ),
                const SizedBox(height: ShowDetailMetrics.sectionGap),
                _Section(
                  title: ShowDetailStrings.noticeSection,
                  child: ShowNotice(paragraphs: detail.notice),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<DateTime>(
        valueListenable: _now,
        builder: (context, now, _) => ShowDetailBottomBar(
          detail: detail,
          now: now,
          onBookPressed: _startBooking,
          onNotifyPressed: () => _notify(ShowDetailStrings.notifyNotReady),
        ),
      ),
    );
  }

  /// 예매를 시작한다. 로그인부터 확인한다.
  ///
  /// 좌석을 다 고르고 결제 직전에 막는 것보다 들어가기 전에 막는 편이 낫다.
  /// 서버는 좌석을 **잡을 때** 요청자를 요구하므로(조회는 누구나 된다) 로그인
  /// 없이도 배치도까지는 그려진다. 그대로 두면 자리를 고르고 확인 다이얼로그까지
  /// 누른 뒤에야 로그인하라는 말을 듣게 된다.
  ///
  /// 로그인 화면은 성공하면 결과로 true 를 넘기며 닫힌다. 돌아오면 고르던
  /// 공연 그대로 예매를 이어 간다.
  Future<void> _startBooking() async {
    if (!AuthSessionScope.of(context).isLoggedIn) {
      final loggedIn = await Navigator.pushNamed(context, AppRoutes.login);
      if (loggedIn != true || !mounted) return;
    }
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.zoneSelection,
      arguments: widget.concertId,
    );
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
