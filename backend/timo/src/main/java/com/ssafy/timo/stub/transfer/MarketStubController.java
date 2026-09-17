package com.ssafy.timo.stub.transfer;

import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.transfer.controller.MarketApi;
import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingDetailResponseDto;
import com.ssafy.timo.domain.transfer.dto.ListingSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketConcertSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketListRequestDto;
import com.ssafy.timo.domain.transfer.dto.MyTradeStatus;
import com.ssafy.timo.domain.transfer.dto.MyTradeSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MyTradeType;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
import com.ssafy.timo.domain.transfer.dto.UpdateListingPriceRequestDto;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TradeStatus;
import com.ssafy.timo.domain.transfer.exception.CannotBuyOwnListingException;
import com.ssafy.timo.domain.transfer.exception.ListPriceExceedsFacePriceException;
import com.ssafy.timo.domain.transfer.exception.ListingAlreadyClosedException;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.exception.ListingPriceMismatchException;
import com.ssafy.timo.domain.transfer.exception.NotListingSellerException;
import com.ssafy.timo.domain.transfer.exception.NotTicketOwnerException;
import com.ssafy.timo.domain.transfer.exception.TicketNotFoundException;
import com.ssafy.timo.domain.transfer.exception.TicketNotListableException;
import com.ssafy.timo.global.storage.ImageStorage;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.ConcertFixture;
import com.ssafy.timo.stub.StubFixtures.MarketTicketFixture;
import com.ssafy.timo.stub.transfer.MarketTicketStore.MarketTicket;
import com.ssafy.timo.stub.concert.ConcertStore;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URI;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * 공식 양도 마켓 API 스텁 (v0).
 *
 * <p>티켓은 {@link MarketTicketStore} 가 들고 있다. 예매 스텁이 주문을 만들며 넣은 티켓을 이쪽이
 * 읽어야 <b>앱이 "예매 → 내 티켓 목록 → 양도 등록" 을 끝까지 눌러 볼 수 있기 때문이다</b>
 * (2026-09-17 변경). 그 전에는 이 컨트롤러가 고정 티켓 6장을 혼자 들고 있어서, 예매로 받은 번호로
 * 등록하면 404 가 났다.
 *
 * <p>고정 티켓은 그대로 남아 있다. 앱이 예매를 하지 않아도 마켓 화면에 볼 것이 있어야 한다.
 *
 * <p>정가의 출처는 v1 과 같다. 둘 다 구역 가격({@code Section.price})을 상한으로 쓴다 - 실제 구현이
 * 공연 단일 정가를 쓰던 시절에는 스텁만 구역 가격이라 달랐으나, 2026-09-17 자로 v1 이 구역 가격으로
 * 옮겨 오면서 맞춰졌다.
 *
 * <p>매물({@link StubListing})과 체결({@link StubTrade})을 티켓과 따로 들고 있다. 실제 구조가
 * {@code ticket} · {@code ticket_listing} · {@code ticket_trade} 세 테이블이고, 한 티켓이 여러 번
 * 등록될 수 있어 매물마다 {@code listingId} 가 새로 생기기 때문이다. <b>외부로 나가는 식별자는
 * {@code listingId} 하나뿐이며 {@code ticketId} 는 이 클래스 밖으로 나가지 않는다.</b>
 *
 * <p>고정 데이터는 남의 매물 5개와 내 보유 티켓 1장({@link StubFixtures#MY_TICKET_TOKEN_ID})이고,
 * 여기에 예매로 생긴 티켓이 더해진다.
 * 구매하면 남의 매물이 내 티켓이 되고, 내 티켓을 등록하면 매물이 되며,
 * 등록 뒤 {@link StubFixtures#LISTING_SOLD_AFTER_SECONDS} 초가 지나면 남이 사 간 것으로 보인다.
 * 그 전이는 조회할 때마다 {@link #settle()} 로 따라잡는다. 스케줄러가 없어도 시간이 흐르면 상태가
 * 바뀐 것처럼 보이고, 테스트는 시계만 돌리면 된다.
 *
 * <p>체결은 <b>202 + {@code PENDING}</b> 이다. 코인 전송과 NFT 이전이 DB 트랜잭션 밖이라 응답
 * 시점에는 아직 끝나지 않았다. 스텁에는 온체인이 없으므로 {@code PENDING} 에서 움직이지 않는다.
 *
 * <p>재현하지 않는 것: 포인트 차감·판매 대금 정산(지갑 도메인), 티켓 이력·입장(티켓 도메인),
 * 잔액 부족 거절, 1인 1매(온체인 {@code AlreadyHoldsShowTicket} 이 맡는다).
 * {@code Idempotency-Key} 는 형식만 검증하고 저장하지 않는다.
 *
 * <p><b>요청자({@code memberId})를 받지만 쓰지 않는다.</b> 스텁의 "내 것" 판정은 고정 데이터가
 * 정하기 때문이다({@code mine} 플래그). 파라미터가 있는 이유는 규약({@code MarketApi})이 모든 경로에
 * 요청자를 요구해서이고, 그 덕에 <b>토큰 없이 부르면 v0 도 401</b> 이다 - v1 과 같은 지점에서 막히는
 * 편이 FE 가 나중에 놀라지 않는다.
 */
@StubController
@RequestMapping(MarketStubController.BASE_PATH)
public class MarketStubController implements MarketApi {

    static final String BASE_PATH = "/api/v0/market";

    private final ConcertStore concertStore;
    private final ImageStorage imageStorage;
    private final Clock clock;
    private final MarketTicketStore ticketStore;
    private final Map<Long, StubListing> listings = new LinkedHashMap<>();
    private final List<StubTrade> trades = new ArrayList<>();

    private long listingSequence = 1L;
    private long tradeSequence = 1L;

    public MarketStubController(MarketTicketStore ticketStore, ConcertStore concertStore,
                                ImageStorage imageStorage, Clock clock) {
        this.ticketStore = ticketStore;
        this.concertStore = concertStore;
        this.imageStorage = imageStorage;
        this.clock = clock;

        // 고정 티켓 중 가격이 정해진 것만 처음부터 매물로 열어 둔다. 티켓 자체는 저장소가 들고 있다.
        for (MarketTicketFixture fixture : StubFixtures.MARKET_TICKETS) {
            if (fixture.listPrice() == null) {
                continue;
            }
            MarketTicket ticket = ticketStore.find(Long.parseLong(fixture.tokenId())).orElseThrow();
            openListing(ticket, fixture.listPrice(), StubFixtures.FIXTURE_LISTED_AT);
        }
    }

    @Override
    public synchronized ResponseEntity<PagedModel<MarketConcertSummaryResponseDto>> findConcerts(
            MarketListRequestDto request, Long memberId) {
        settle();

        // 공연마다 매물 수와 최저가만 모은다. 실제 구현은 group by 한 번이다.
        Map<Long, List<StubListing>> byConcert = new LinkedHashMap<>();
        for (StubListing listing : listings.values()) {
            if (listing.status == ListingStatus.LISTED) {
                byConcert.computeIfAbsent(listing.ticket.concertId(), id -> new ArrayList<>()).add(listing);
            }
        }

        List<MarketConcertSummaryResponseDto> matched = byConcert.entrySet().stream()
                .map(entry -> {
                    ConcertFixture concert = concertStore.find(entry.getKey()).orElseThrow();
                    long lowest = entry.getValue().stream().mapToLong(listing -> listing.price).min().orElseThrow();
                    return new MarketConcertSummaryResponseDto(
                            concert.id(),
                            concert.title(),
                            imageStorage.getUrl(concert.posterImageKey()),
                            concert.startDate(),
                            concert.endDate(),
                            concert.venueName(),
                            entry.getValue().size(),
                            lowest);
                })
                // 임박한 공연부터. 일정이 비어 있는 공연은 뒤로 민다.
                .sorted(Comparator
                        .comparing(MarketConcertSummaryResponseDto::startDate,
                                Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(MarketConcertSummaryResponseDto::concertId))
                .toList();

        return ResponseEntity.ok(page(matched, request, Sort.by(Sort.Order.asc("startDate"))));
    }

    @Override
    public synchronized ResponseEntity<PagedModel<ListingSummaryResponseDto>> findListings(
            Long concertId, MarketListRequestDto request, Long memberId) {
        settle();
        concertStore.find(concertId).orElseThrow(() -> new ConcertNotFoundException(concertId));

        List<ListingSummaryResponseDto> matched = listings.values().stream()
                .filter(listing -> listing.status == ListingStatus.LISTED)
                .filter(listing -> listing.ticket.concertId() == concertId)
                // 낮은 가격순. 동가는 listingId 오름차순으로 고정해 페이지를 넘길 때 같은 매물이 두 번 나오지 않게 한다.
                .sorted(Comparator.comparingLong((StubListing listing) -> listing.price)
                        .thenComparingLong(listing -> listing.listingId))
                .map(this::toSummary)
                .toList();

        return ResponseEntity.ok(page(matched, request, Sort.by(Sort.Order.asc("price"))));
    }

    @Override
    public synchronized ResponseEntity<ListingDetailResponseDto> findListing(Long listingId, Long memberId) {
        settle();
        // 팔렸거나 취소된 매물도 조회된다. 상세로 들어가는 사이에 팔릴 수 있기 때문이다.
        StubListing listing = Optional.ofNullable(listings.get(listingId))
                .orElseThrow(() -> new ListingNotFoundException(listingId));

        return ResponseEntity.ok(toDetail(listing));
    }

    @Override
    public synchronized ResponseEntity<PagedModel<MyTradeSummaryResponseDto>> findMyTrades(
            MarketListRequestDto request, Long memberId) {
        settle();
        List<MyTradeSummaryResponseDto> matched = new ArrayList<>();

        for (StubListing listing : listings.values()) {
            if (listing.listedByMe) {
                matched.add(toMySale(listing));
            }
        }
        for (StubTrade trade : trades) {
            matched.add(toMyPurchase(trade));
        }

        // 최신순. 동점은 listingId 내림차순으로 고정한다.
        List<MyTradeSummaryResponseDto> sorted = matched.stream()
                .sorted(Comparator.comparing(MyTradeSummaryResponseDto::occurredAt)
                        .thenComparing(MyTradeSummaryResponseDto::listingId)
                        .reversed())
                .toList();

        return ResponseEntity.ok(page(sorted, request, Sort.by(Sort.Order.desc("occurredAt"))));
    }

    @Override
    public synchronized ResponseEntity<ListingDetailResponseDto> list(CreateListingRequestDto request,
                                                                      Long memberId) {
        settle();
        MarketTicket ticket = ticketStore.find(request.ticketId())
                .orElseThrow(() -> new TicketNotFoundException(request.ticketId()));
        if (!ticket.mine()) {
            throw new NotTicketOwnerException(ticket.ticketId());
        }
        if (ticket.listed()) {
            throw new TicketNotListableException(ticket.ticketId(), "이미 등록 중");
        }
        if (request.price() > ticket.faceValue()) {
            throw new ListPriceExceedsFacePriceException(request.price(), ticket.faceValue());
        }

        StubListing listing = openListing(ticket, request.price(), LocalDateTime.now(clock));

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/listings/" + listing.listingId))
                .body(toDetail(listing));
    }

    @Override
    public synchronized ResponseEntity<ListingDetailResponseDto> updatePrice(
            Long listingId, UpdateListingPriceRequestDto request, Long memberId) {
        settle();
        StubListing listing = Optional.ofNullable(listings.get(listingId))
                .orElseThrow(() -> new ListingNotFoundException(listingId));
        // 검사 순서는 실제 구현과 같다. 매물 존재 -> 등록자 -> 정가 -> 매물 상태.
        if (!listing.listedByMe) {
            throw new NotListingSellerException(listingId);
        }
        if (request.price() > listing.ticket.faceValue()) {
            throw new ListPriceExceedsFacePriceException(request.price(), listing.ticket.faceValue());
        }
        if (listing.status != ListingStatus.LISTED) {
            throw new ListingAlreadyClosedException(listingId);
        }

        listing.price = request.price();

        return ResponseEntity.ok(toDetail(listing));
    }

    @Override
    public synchronized ResponseEntity<Void> cancel(Long listingId, Long memberId) {
        settle();
        StubListing listing = Optional.ofNullable(listings.get(listingId))
                .orElseThrow(() -> new ListingNotFoundException(listingId));
        if (!listing.listedByMe) {
            throw new NotListingSellerException(listingId);
        }
        // 상태 판정은 조회가 아니라 전이의 결과로 한다. 실제 구현은 조건부 UPDATE 의 영향 행 수다.
        if (listing.status != ListingStatus.LISTED) {
            throw new ListingAlreadyClosedException(listingId);
        }

        close(listing, ListingStatus.CANCELED);
        listing.ticket.currentListingId(null);

        return ResponseEntity.noContent().build();
    }

    @Override
    public synchronized ResponseEntity<PurchaseResponseDto> purchase(
            Long listingId, String idempotencyKey, PurchaseRequestDto request, Long memberId) {
        settle();
        StubListing listing = Optional.ofNullable(listings.get(listingId))
                .orElseThrow(() -> new ListingNotFoundException(listingId));

        // 검사 순서는 실제 구현과 같다. 매물 상태 -> 가격 -> 내 매물.
        if (listing.status != ListingStatus.LISTED) {
            throw new ListingAlreadyClosedException(listingId);
        }
        if (request.expectedPrice() != listing.price) {
            throw new ListingPriceMismatchException(listingId);
        }
        if (listing.listedByMe) {
            throw new CannotBuyOwnListingException(listingId);
        }

        LocalDateTime now = LocalDateTime.now(clock);
        close(listing, ListingStatus.SOLD);

        // 소유자 교체는 온체인이 정본이라 실제 구현에서는 보류돼 있다. 스텁은 화면 흐름을 위해 바꾼다.
        listing.ticket.changeOwnerToMe(true);
        listing.ticket.currentListingId(null);

        StubTrade trade = new StubTrade(tradeSequence++, listing, now);
        trades.add(trade);

        ConcertFixture concert = concertOf(listing.ticket);
        return ResponseEntity.accepted().body(new PurchaseResponseDto(
                trade.tradeId,
                listing.listingId,
                trade.status,
                listing.price,
                concert.title(),
                concert.startDate(),
                concert.venueName(),
                listing.ticket.seat().section().name(),
                listing.ticket.seat().seatNo(),
                listing.ticket.seat().seatCol(),
                trade.tradedAt));
    }

    private StubListing openListing(MarketTicket ticket, long price, LocalDateTime listedAt) {
        StubListing listing = new StubListing(listingSequence++, ticket, price, ticket.mine(), listedAt);
        listings.put(listing.listingId, listing);
        ticket.currentListingId(listing.listingId);
        return listing;
    }

    private void close(StubListing listing, ListingStatus status) {
        listing.status = status;
        listing.closedAt = LocalDateTime.now(clock);
    }

    /** 내 매물 중 팔릴 시각이 지난 것을 남에게 넘긴다. 멱등이라 몇 번 불려도 같다. */
    private void settle() {
        LocalDateTime now = LocalDateTime.now(clock);
        for (StubListing listing : listings.values()) {
            if (listing.listedByMe
                    && listing.status == ListingStatus.LISTED
                    && !listing.listedAt.plusSeconds(StubFixtures.LISTING_SOLD_AFTER_SECONDS).isAfter(now)) {
                listing.status = ListingStatus.SOLD;
                listing.closedAt = now;
                listing.ticket.changeOwnerToMe(false);
                listing.ticket.currentListingId(null);
            }
        }
    }

    private <T> PagedModel<T> page(List<T> all, MarketListRequestDto request, Sort sort) {
        Pageable pageable = request.toPageable(sort);
        int from = (int) Math.min(pageable.getOffset(), all.size());
        int to = Math.min(from + pageable.getPageSize(), all.size());

        return new PagedModel<>(new PageImpl<>(all.subList(from, to), pageable, all.size()));
    }

    private ListingSummaryResponseDto toSummary(StubListing listing) {
        return new ListingSummaryResponseDto(
                listing.listingId,
                listing.ticket.seat().section().name(),
                SeatGrade.COMMON,
                listing.ticket.seat().seatNo(),
                listing.ticket.seat().seatCol(),
                listing.price,
                listing.ticket.faceValue(),
                discountRate(listing),
                listing.listedByMe,
                listing.listedAt);
    }

    private ListingDetailResponseDto toDetail(StubListing listing) {
        ConcertFixture concert = concertOf(listing.ticket);

        return new ListingDetailResponseDto(
                listing.listingId,
                listing.status,
                concert.id(),
                concert.title(),
                imageStorage.getUrl(concert.posterImageKey()),
                concert.startDate(),
                concert.venueName(),
                listing.ticket.seat().section().name(),
                SeatGrade.COMMON,
                listing.ticket.seat().seatNo(),
                listing.ticket.seat().seatCol(),
                listing.price,
                listing.ticket.faceValue(),
                discountRate(listing),
                listing.listedByMe,
                listing.listedAt,
                listing.closedAt);
    }

    private MyTradeSummaryResponseDto toMySale(StubListing listing) {
        ConcertFixture concert = concertOf(listing.ticket);

        return new MyTradeSummaryResponseDto(
                MyTradeType.SALE,
                null,
                listing.listingId,
                MyTradeStatus.of(listing.status),
                concert.id(),
                concert.title(),
                imageStorage.getUrl(concert.posterImageKey()),
                concert.startDate(),
                concert.venueName(),
                listing.ticket.seat().section().name(),
                SeatGrade.COMMON,
                listing.ticket.seat().seatNo(),
                listing.ticket.seat().seatCol(),
                listing.price,
                listing.ticket.faceValue(),
                listing.listedAt);
    }

    private MyTradeSummaryResponseDto toMyPurchase(StubTrade trade) {
        StubListing listing = trade.listing;
        ConcertFixture concert = concertOf(listing.ticket);

        return new MyTradeSummaryResponseDto(
                MyTradeType.PURCHASE,
                trade.tradeId,
                listing.listingId,
                MyTradeStatus.of(trade.status),
                concert.id(),
                concert.title(),
                imageStorage.getUrl(concert.posterImageKey()),
                concert.startDate(),
                concert.venueName(),
                listing.ticket.seat().section().name(),
                SeatGrade.COMMON,
                listing.ticket.seat().seatNo(),
                listing.ticket.seat().seatCol(),
                listing.price,
                listing.ticket.faceValue(),
                trade.tradedAt);
    }

    private int discountRate(StubListing listing) {
        long faceValue = listing.ticket.faceValue();
        if (faceValue <= 0) {
            return 0;
        }
        // 계산 방식은 TicketListing.discountRate 와 같다 - 금액 단위가 wei 면 long 곱셈이 넘친다.
        return BigDecimal.valueOf(faceValue - listing.price)
                .multiply(BigDecimal.valueOf(100))
                .divide(BigDecimal.valueOf(faceValue), 0, RoundingMode.FLOOR)
                .intValue();
    }

    private ConcertFixture concertOf(MarketTicket ticket) {
        return concertStore.find(ticket.concertId()).orElseThrow();
    }


    /** 매물 하나. 한 티켓이 여러 번 등록될 수 있어 티켓과 따로 둔다. */
    private static final class StubListing {

        private final long listingId;
        private final MarketTicket ticket;
        /** 열려 있는 동안 판매자가 바꿀 수 있다. 실제 구현도 이 값만 가변이다. */
        private long price;
        /** 등록한 사람이 나인가. 티켓의 소유자는 바뀌지만 이 값은 등록 시점에 고정된다. */
        private final boolean listedByMe;
        private final LocalDateTime listedAt;
        private ListingStatus status = ListingStatus.LISTED;
        private LocalDateTime closedAt;

        StubListing(long listingId, MarketTicket ticket, long price, boolean listedByMe, LocalDateTime listedAt) {
            this.listingId = listingId;
            this.ticket = ticket;
            this.price = price;
            this.listedByMe = listedByMe;
            this.listedAt = listedAt;
        }
    }

    /** 내가 사들인 체결 하나. 온체인이 없어 {@link TradeStatus#PENDING} 에서 움직이지 않는다. */
    private static final class StubTrade {

        private final long tradeId;
        private final StubListing listing;
        private final LocalDateTime tradedAt;
        private final TradeStatus status = TradeStatus.PENDING;

        StubTrade(long tradeId, StubListing listing, LocalDateTime tradedAt) {
            this.tradeId = tradeId;
            this.listing = listing;
            this.tradedAt = tradedAt;
        }
    }
}
