import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/listable_ticket.dart';
import '../models/listing.dart';
import '../models/listing_detail.dart';
import '../models/listing_status.dart';
import '../models/market_concert.dart';
import '../models/my_trade.dart';
import '../models/purchased_trade.dart';
import '../models/trade_status.dart';
import 'resale_api.dart';

/// 가짜 [ResaleApi] 가 무엇을 돌려줄지.
enum ResaleMockScenario {
  /// 시안 그대로. 공연 넷 · 매물 여덟 · 등록할 수 있는 내 티켓 둘. 여기에
  /// 내 티켓의 양도 목록 탭에서 '판매 완료' 카드를 보려고 팔린 내 매물 하나를
  /// 더 둔다 — 마켓 화면에는 나오지 않는다.
  design,

  /// 공연 목록도 내 티켓도 비어 있다. 빈 화면 문구를 볼 때.
  empty,

  /// 모든 요청이 실패한다. 오류 화면과 다시 시도를 볼 때.
  error,
}

/// 서버 없이 쓰는 가짜 [ResaleApi]. 테스트와 시안 확인용이다 —
/// `flutter run --dart-define=RESALE_API=mock`.
///
/// 상태를 실제로 바꾼다. 사면 그 매물이 목록에서 사라지고, 등록하면 내 티켓이
/// 목록에서 빠지며 그 공연의 매물 수가 는다. 화면이 서버 없이도 흐름대로
/// 움직이는지 눈으로 확인하기 위해서다.
///
/// **날짜는 실행 시각 기준 상대값이다.** 시안에 적힌 날짜(2026.02.20 등)를
/// 그대로 박으면 그 날이 지나는 순간 전부 지난 공연이 된다. 공연명·장소·좌석·
/// 가격은 시안 그대로다.
///
/// 포스터만은 백엔드가 필요하다. 주소가 백엔드의 정적 파일을 가리켜서, 서버를
/// 안 띄우면 회색 자리가 그려진다. 앱 에셋으로 두면 화면이 받는 값이 서버
/// 응답과 달라져, 정작 연동했을 때 포스터가 깨지는 것을 목으로는 못 잡는다.
class MockResaleApi implements ResaleApi {
  MockResaleApi({
    this.latency = ResaleMetrics.mockLatency,
    this.scenario = ResaleMockScenario.design,
    this.clock = DateTime.now,
  });

  final Duration latency;
  final ResaleMockScenario scenario;

  /// 지금 시각을 읽는 함수. 공연 날짜와 체결 시각을 여기서 잰다.
  ///
  /// 테스트가 시각을 고정할 수 있게 받는다(`MockTicketApi` 와 같은 이유다).
  final DateTime Function() clock;

  /// 내가 산 체결이 온체인까지 끝난 것으로 보이기까지의 시간.
  ///
  /// 결제 완료 화면이 '티켓 양도 중' 에서 '티켓 양도 완료' 로 바뀌는 것을
  /// 보려면 기다릴 시간이 필요하다. 백엔드 스텁의
  /// `LISTING_SOLD_AFTER_SECONDS`(10초)와 같은 장치다.
  static const confirmAfter = Duration(seconds: 6);

  List<_MockListing>? _listings;
  List<ListableTicket>? _tickets;
  final _trades = <int, _MockTrade>{};
  int _nextListingId = 100;
  int _nextTradeId = 1;

  @override
  Future<List<MarketConcert>> fetchConcerts() async {
    await _respond();
    if (scenario == ResaleMockScenario.empty) return const [];

    // 매물이 있는 공연만, 공연마다 매물 수와 최저가를 모은다. 서버가 group by
    // 한 번으로 하는 일이다 — 매물 0 인 공연은 내보내지 않는다. 시안의 공연
    // 카드에는 `0 건` 이 있지만, 들어가 봐야 빈 화면인 공연은 서버가 주지 않는다.
    final grouped = <int, List<_MockListing>>{};
    for (final listing in _openListings) {
      grouped.putIfAbsent(listing.concertId, () => []).add(listing);
    }

    return [
      for (final concert in _concerts)
        if (grouped[concert.concertId] case final listings?)
          MarketConcert(
            concertId: concert.concertId,
            title: concert.title,
            venueName: concert.venueName,
            listingCount: listings.length,
            lowestPrice: listings
                .map((listing) => listing.price)
                .reduce((a, b) => a < b ? a : b),
            posterImageUrl: concert.posterImageUrl,
            startAt: concert.startAt,
            endAt: concert.endAt,
          ),
    ];
  }

  @override
  Future<List<Listing>> fetchListings(int concertId) async {
    await _respond();
    return [
      for (final listing in _openListings)
        if (listing.concertId == concertId) listing.toSummary(),
    ];
  }

  @override
  Future<ListingDetail> fetchListing(int listingId) async {
    await _respond();
    final listing = _find(listingId);
    return listing.toDetail(_concertOf(listing.concertId));
  }

  @override
  Future<PurchasedTrade> purchase({
    required int listingId,
    required int expectedPrice,
    required String idempotencyKey,
  }) async {
    await _respond();
    final listing = _find(listingId);
    // 검사 순서는 서버와 같다. 매물 상태 -> 가격 -> 내 매물.
    if (listing.status != ListingStatus.listed) {
      throw const ApiException('이미 팔렸거나 내려간 매물이에요.', status: 409);
    }
    if (listing.price != expectedPrice) {
      throw const ApiException('가격이 바뀌었어요. 다시 확인해주세요.', status: 409);
    }
    if (listing.mine) {
      throw const ApiException('내가 등록한 매물은 살 수 없어요.', status: 409);
    }

    final now = clock();
    listing.status = ListingStatus.sold;
    listing.closedAt = now;

    final concert = _concertOf(listing.concertId);
    final trade = _MockTrade(
      id: _nextTradeId++,
      listingId: listing.listingId,
      tradedAt: now,
    );
    _trades[trade.id] = trade;

    return PurchasedTrade(
      tradeId: trade.id,
      listingId: listing.listingId,
      status: TradeStatus.pending,
      price: listing.price,
      concertTitle: concert.title,
      venueName: concert.venueName,
      sectionName: listing.sectionName,
      seatRow: listing.seatRow,
      seatNumber: listing.seatNumber,
      tradedAt: now,
      startAt: concert.startAt,
    );
  }

  @override
  Future<TradeStatus> fetchTradeStatus(int tradeId) async {
    await _respond();
    final trade = _trades[tradeId];
    return trade == null ? TradeStatus.pending : _tradeStatusOf(trade);
  }

  /// 체결한 지 [confirmAfter] 가 지났으면 끝난 것으로 본다. 실제 서버에서
  /// 온체인 전송이 끝나는 것을 시간으로 흉내 낸 것이다.
  TradeStatus _tradeStatusOf(_MockTrade trade) =>
      clock().difference(trade.tradedAt) >= confirmAfter
      ? TradeStatus.confirmed
      : TradeStatus.pending;

  @override
  Future<List<ListableTicket>> fetchListableTickets() async {
    await _respond();
    if (scenario == ResaleMockScenario.empty) return const [];
    return List.unmodifiable(_tickets ??= _initialTickets());
  }

  @override
  Future<ListingDetail> createListing({
    required int ticketId,
    required int price,
  }) async {
    await _respond();
    final tickets = _tickets ??= _initialTickets();
    final index = tickets.indexWhere((ticket) => ticket.ticketId == ticketId);
    if (index < 0) {
      throw const ApiException('이미 등록했거나 없는 티켓이에요.', status: 404);
    }
    final ticket = tickets[index];
    if (price > ticket.facePrice) {
      throw const ApiException('정가보다 비싸게는 등록할 수 없어요.', status: 400);
    }

    // 등록하면 티켓은 내 손을 떠난다(LISTED). 목록에서 빼야 같은 티켓이 등록
    // 화면에 다시 나오지 않는다.
    tickets.removeAt(index);

    final concert = _concertOf(_concertIdOfTicket(ticket));
    final listing = _MockListing(
      listingId: _nextListingId++,
      concertId: concert.concertId,
      sectionName: ticket.sectionName,
      seatRow: ticket.seatRow,
      seatNumber: ticket.seatNumber,
      price: price,
      faceValue: ticket.facePrice,
      mine: true,
      listedAt: clock(),
      ticket: ticket,
    );
    (_listings ??= _initialListings()).add(listing);

    return listing.toDetail(concert);
  }

  /// 내가 올린 매물 전부(팔린 것·내린 것 포함)와 내가 산 체결을 한 목록으로.
  /// 최근 것부터다 — 화면이 위에서부터 읽는 순서다.
  @override
  Future<List<MyTrade>> fetchMyTrades() async {
    await _respond();
    if (scenario == ResaleMockScenario.empty) return const [];

    final trades = [
      for (final listing in _listings ??= _initialListings())
        if (listing.mine)
          listing.toMyTrade(
            _concertOf(listing.concertId),
            type: MyTradeType.sale,
            status: MyTradeStatus.fromWire(listing.status.wireName),
            occurredAt: listing.listedAt,
          ),
      for (final trade in _trades.values) _purchaseOf(trade),
    ];
    trades.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return trades;
  }

  /// 내가 산 체결 하나를 내 거래 내역 항목으로. 공연·좌석·가격은 산 매물의 것,
  /// 상태는 체결 시각으로 만든다([_tradeStatusOf]).
  MyTrade _purchaseOf(_MockTrade trade) {
    final listing = _find(trade.listingId);
    return listing.toMyTrade(
      _concertOf(listing.concertId),
      type: MyTradeType.purchase,
      status: MyTradeStatus.fromWire(_tradeStatusOf(trade).wireName),
      occurredAt: trade.tradedAt,
      tradeId: trade.id,
    );
  }

  @override
  Future<void> cancelListing(int listingId) async {
    await _respond();
    final listing = _find(listingId);
    // 서버와 같은 판정이다. 남의 매물은 403, 이미 닫힌 매물은 409.
    if (!listing.mine) {
      throw const ApiException('내가 등록한 매물이 아니에요.', status: 403);
    }
    if (listing.status != ListingStatus.listed) {
      throw const ApiException('이미 팔렸거나 내려간 매물이에요.', status: 409);
    }

    listing.status = ListingStatus.canceled;
    listing.closedAt = clock();
    // 내리면 티켓은 다시 내 손으로 돌아온다. 등록 화면 목록에 다시 나와야
    // 재등록이 된다 — 등록할 때 뺐던 것을 되돌리는 것이다.
    final ticket = listing.ticket;
    if (ticket != null) (_tickets ??= _initialTickets()).add(ticket);
  }

  @override
  Future<ListingDetail> updateListingPrice({
    required int listingId,
    required int price,
  }) async {
    await _respond();
    final listing = _find(listingId);
    // 검사 순서는 서버와 같다. 내 매물 -> 매물 상태 -> 가격.
    if (!listing.mine) {
      throw const ApiException('내가 등록한 매물이 아니에요.', status: 403);
    }
    if (listing.status != ListingStatus.listed) {
      throw const ApiException('이미 팔렸거나 내려간 매물이에요.', status: 409);
    }
    if (price > listing.faceValue) {
      throw const ApiException('정가보다 비싸게는 등록할 수 없어요.', status: 400);
    }

    listing.price = price;
    return listing.toDetail(_concertOf(listing.concertId));
  }

  Iterable<_MockListing> get _openListings => (_listings ??= _initialListings())
      .where((listing) => listing.status == ListingStatus.listed);

  _MockListing _find(int listingId) {
    final listings = _listings ??= _initialListings();
    final index = listings.indexWhere(
      (listing) => listing.listingId == listingId,
    );
    if (index < 0) {
      throw const ApiException('없는 매물이에요.', status: 404);
    }
    return listings[index];
  }

  /// 응답 지연과 실패 시나리오. 모든 메서드가 여기를 먼저 지난다.
  Future<void> _respond() async {
    await Future<void>.delayed(latency);
    if (scenario == ResaleMockScenario.error) {
      throw const ApiException('양도마켓을 불러오지 못했어요.', status: 500);
    }
  }

  _MockConcert _concertOf(int concertId) =>
      _concerts.firstWhere((concert) => concert.concertId == concertId);

  /// 내 티켓이 어느 공연 것인지. 목 데이터가 시안의 공연명을 그대로 쓰므로
  /// 제목으로 잇는다. 공연 목록에 없는 공연(아이유 콘서트)이면 첫 공연으로
  /// 둔다 — 등록한 매물이 어느 공연에도 안 붙으면 목록에서 사라져 버린다.
  int _concertIdOfTicket(ListableTicket ticket) => _concerts
      .firstWhere(
        (concert) => concert.title == ticket.concertTitle,
        orElse: () => _concerts.first,
      )
      .concertId;

  /// 공연 넷. 제목·장소는 시안 그대로, 날짜만 실행 시각 기준이다.
  late final List<_MockConcert> _concerts = _initialConcerts();

  List<_MockConcert> _initialConcerts() {
    final now = clock();
    return [
      _MockConcert(
        concertId: 1,
        title: '2026 BIGBANG',
        venueName: '올림픽공원 체조경기장',
        posterImageUrl: 'poster/poster_main_kim_feel.gif',
        startAt: now.add(const Duration(days: 12)),
      ),
      _MockConcert(
        concertId: 2,
        title: '2027 블랙핑크',
        venueName: '올림픽공원 체조경기장',
        posterImageUrl: 'poster/poster_main_lee.gif',
        startAt: now.add(const Duration(days: 40)),
      ),
      _MockConcert(
        concertId: 3,
        title: '2026 BTS 콘서트',
        venueName: '고척스카이돔',
        posterImageUrl: 'poster/poster_main_roykim.jpg',
        startAt: now.add(const Duration(days: 68)),
      ),
      _MockConcert(
        concertId: 4,
        title: '2027 RE:MIND',
        venueName: '블루스퀘어 마스터카드홀',
        posterImageUrl: 'poster/poster_main_mars.gif',
        startAt: now.add(const Duration(days: 96)),
      ),
    ];
  }

  /// 매물 여덟. 첫 공연에 넷을 몰아 둔다 — 시안의 매물 목록이 그 화면이다.
  ///
  /// 시안의 매물 줄은 정가 186,000원에 -12% 라고 적혀 있지만 함께 적힌 등록가
  /// (176,000원)와 맞지 않는다. 할인율은 서버가 정가와 등록가에서 계산해 주는
  /// 값이라 여기서도 계산해 넣어, 화면의 세 숫자가 서로 맞게 한다.
  List<_MockListing> _initialListings() {
    final listedAt = clock().subtract(const Duration(hours: 5));
    return [
      _MockListing(
        listingId: 1,
        concertId: 1,
        sectionName: 'R구역',
        seatRow: 8,
        seatNumber: 19,
        price: 176000,
        faceValue: 186000,
        listedAt: listedAt,
      ),
      _MockListing(
        listingId: 2,
        concertId: 1,
        sectionName: 'S구역',
        seatRow: 3,
        seatNumber: 12,
        price: 168000,
        faceValue: 186000,
        listedAt: listedAt.add(const Duration(minutes: 40)),
      ),
      _MockListing(
        listingId: 3,
        concertId: 1,
        sectionName: 'R구역',
        seatRow: 15,
        seatNumber: 7,
        price: 163000,
        faceValue: 186000,
        listedAt: listedAt.add(const Duration(hours: 1)),
      ),
      _MockListing(
        listingId: 4,
        concertId: 1,
        sectionName: 'A구역',
        seatRow: 21,
        seatNumber: 33,
        price: 150000,
        faceValue: 186000,
        listedAt: listedAt.add(const Duration(hours: 2)),
      ),
      _MockListing(
        listingId: 5,
        concertId: 2,
        sectionName: 'VIP구역',
        seatRow: 2,
        seatNumber: 5,
        price: 143000,
        faceValue: 154000,
        listedAt: listedAt.add(const Duration(minutes: 10)),
      ),
      _MockListing(
        listingId: 6,
        concertId: 3,
        sectionName: 'R구역',
        seatRow: 9,
        seatNumber: 14,
        price: 99000,
        faceValue: 121000,
        listedAt: listedAt.add(const Duration(minutes: 25)),
      ),
      _MockListing(
        listingId: 7,
        concertId: 3,
        sectionName: 'S구역',
        seatRow: 6,
        seatNumber: 28,
        price: 90000,
        faceValue: 121000,
        listedAt: listedAt.add(const Duration(hours: 3)),
      ),
      // 내가 올린 매물. 목록에서 구분되고 구매가 막힌다.
      _MockListing(
        listingId: 8,
        concertId: 4,
        sectionName: 'R구역',
        seatRow: 11,
        seatNumber: 2,
        price: 132000,
        faceValue: 143000,
        mine: true,
        listedAt: listedAt.add(const Duration(hours: 4)),
      ),
      // 팔린 내 매물. 마켓에는 안 나오고 내 티켓의 양도 목록 탭에서만 보인다.
      _MockListing(
          listingId: 9,
          concertId: 1,
          sectionName: 'S구역',
          seatRow: 5,
          seatNumber: 8,
          price: 170000,
          faceValue: 186000,
          mine: true,
          listedAt: listedAt.add(const Duration(minutes: 30)),
        )
        ..status = ListingStatus.sold
        ..closedAt = listedAt.add(const Duration(hours: 3)),
    ];
  }

  /// 등록할 수 있는 내 티켓 둘. 공연명·장소·좌석·정가는 시안 그대로다.
  List<ListableTicket> _initialTickets() {
    final now = clock();
    return [
      ListableTicket(
        ticketId: 101,
        concertTitle: '2027 RE:MIND',
        venueName: '올림픽공원 체조경기장',
        sectionName: 'R구역',
        seatRow: 12,
        seatNumber: 24,
        facePrice: 198600,
        posterImageUrl: 'poster/poster_main_mars.gif',
        startAt: now.add(const Duration(days: 96)),
      ),
      ListableTicket(
        ticketId: 102,
        concertTitle: '2026 아이유 콘서트',
        venueName: '블루스퀘어 마스터카드홀',
        sectionName: 'VIP구역',
        seatRow: 5,
        seatNumber: 10,
        facePrice: 165000,
        posterImageUrl: 'poster/poster_main_kim_feel.gif',
        startAt: now.add(const Duration(days: 30)),
      ),
    ];
  }
}

/// 목이 들고 있는 공연 하나. 서버 응답 모델과 달리 매물 수·최저가가 없다 —
/// 그 둘은 매물에서 세는 값이라 여기 두면 두 벌이 어긋난다.
class _MockConcert {
  const _MockConcert({
    required this.concertId,
    required this.title,
    required this.venueName,
    required this.posterImageUrl,
    required this.startAt,
  });

  final int concertId;
  final String title;
  final String venueName;
  final String posterImageUrl;
  final DateTime startAt;

  /// 시안의 공연은 모두 하루짜리다.
  DateTime get endAt => startAt.add(const Duration(hours: 2));
}

/// 목이 들고 있는 매물 하나. 팔리거나 내려가면 상태가, 가격을 고치면 등록가가
/// 바뀌므로 가변이다.
class _MockListing {
  _MockListing({
    required this.listingId,
    required this.concertId,
    required this.sectionName,
    required this.seatRow,
    required this.seatNumber,
    required this.price,
    required this.faceValue,
    required this.listedAt,
    this.mine = false,
    this.ticket,
  });

  final int listingId;
  final int concertId;
  final String sectionName;

  /// 목은 좌석을 늘 채운다. 서버가 좌석을 실어 주기 시작했을 때의 화면을
  /// 먼저 보기 위해서다.
  final int seatRow;
  final int seatNumber;

  /// 등록가. 판매자가 고칠 수 있는 유일한 값이다(`updateListingPrice`).
  int price;
  final int faceValue;
  final bool mine;
  final DateTime listedAt;

  /// 이 매물이 된 내 티켓. 등록 화면에서 올린 매물에만 있다 — 내리면 그 티켓이
  /// 등록 화면 목록으로 돌아가야 재등록이 된다. 처음부터 있던 내 매물은 null.
  final ListableTicket? ticket;

  ListingStatus status = ListingStatus.listed;
  DateTime? closedAt;

  /// 서버가 정가와 등록가에서 계산해 주는 할인율(%).
  int get discountRate =>
      faceValue <= 0 ? 0 : ((faceValue - price) * 100) ~/ faceValue;

  Listing toSummary() => Listing(
    listingId: listingId,
    sectionName: sectionName,
    seatRow: seatRow,
    seatNumber: seatNumber,
    price: price,
    faceValue: faceValue,
    discountRate: discountRate,
    mine: mine,
    listedAt: listedAt,
  );

  ListingDetail toDetail(_MockConcert concert) => ListingDetail(
    listingId: listingId,
    status: status,
    concertId: concert.concertId,
    concertTitle: concert.title,
    venueName: concert.venueName,
    sectionName: sectionName,
    seatRow: seatRow,
    seatNumber: seatNumber,
    price: price,
    faceValue: faceValue,
    discountRate: discountRate,
    mine: mine,
    listedAt: listedAt,
    posterImageUrl: concert.posterImageUrl,
    startAt: concert.startAt,
    closedAt: closedAt,
  );

  /// 내 거래 내역 항목으로. 판매면 등록 시각을, 구매면 체결 번호와 체결 시각을
  /// 받는다 — 서버가 두 종류를 한 모양으로 내보내는 것과 같다.
  MyTrade toMyTrade(
    _MockConcert concert, {
    required MyTradeType type,
    required MyTradeStatus status,
    required DateTime occurredAt,
    int? tradeId,
  }) => MyTrade(
    type: type,
    tradeId: tradeId,
    listingId: listingId,
    status: status,
    concertId: concert.concertId,
    concertTitle: concert.title,
    venueName: concert.venueName,
    sectionName: sectionName,
    seatRow: seatRow,
    seatNumber: seatNumber,
    price: price,
    faceValue: faceValue,
    occurredAt: occurredAt,
    posterImageUrl: concert.posterImageUrl,
    startAt: concert.startAt,
  );
}

/// 목이 들고 있는 체결 하나. 언제 무엇을 샀는지만 알면 상태는 시간으로,
/// 나머지는 매물에서 만들 수 있다.
class _MockTrade {
  const _MockTrade({
    required this.id,
    required this.listingId,
    required this.tradedAt,
  });

  final int id;

  /// 산 매물. 내 거래 내역이 공연·좌석·가격을 여기서 가져온다.
  final int listingId;

  final DateTime tradedAt;
}
