package com.ssafy.timo.stub.transfer;

import com.ssafy.timo.domain.reservation.exception.AlreadyReservedException;
import com.ssafy.timo.domain.transfer.controller.MarketApi;
import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingListRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingResponseDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
import com.ssafy.timo.domain.transfer.exception.CannotBuyOwnListingException;
import com.ssafy.timo.domain.transfer.exception.ListPriceExceedsFacePriceException;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.exception.NotTicketOwnerException;
import com.ssafy.timo.domain.transfer.exception.TicketNotFoundException;
import com.ssafy.timo.domain.transfer.exception.TicketNotListableException;
import com.ssafy.timo.global.storage.ImageStorage;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.ConcertFixture;
import com.ssafy.timo.stub.StubFixtures.MarketTicketFixture;
import com.ssafy.timo.stub.StubFixtures.SeatFixture;
import com.ssafy.timo.stub.StubHashes;
import com.ssafy.timo.stub.concert.ConcertStore;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

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
 * <p>티켓 도메인이 아직 없어 필요한 최소한의 티켓 상태를 이 컨트롤러가 직접 들고 있다
 * ({@link MarketTicket}). tokenId 하나에 공연·좌석·정가·소유자·등록가가 붙어 있으면 마켓은 성립한다.
 * <b>TODO</b>: 티켓 도메인이 생기면 이 상태를 그쪽 미러 테이블로 옮기고 여기서는 조회만 한다.
 *
 * <p>고정 데이터는 남의 매물 5개와 내 보유 티켓 1장({@link StubFixtures#MY_TICKET_TOKEN_ID})이다.
 * 구매하면 남의 매물이 내 티켓이 되고, 내 티켓을 등록하면 매물이 되며,
 * 등록 뒤 {@link StubFixtures#LISTING_SOLD_AFTER_SECONDS} 초가 지나면 남이 사 간 것으로 보인다.
 * 그 전이는 조회할 때마다 {@link #settle()} 로 따라잡는다. 스케줄러가 없어도 시간이 흐르면 상태가 바뀐 것처럼
 * 보이고, 테스트는 시계만 돌리면 된다.
 *
 * <p>검사 순서는 컨트랙트와 같다. 등록은 티켓 존재 → 소유자 → 상태 → 가격, 구매는 매물 존재 → 내 매물 → 1인 1매.
 *
 * <p>포인트 차감·판매 대금 정산은 지갑 도메인, 티켓 이력·입장은 티켓 도메인의 일이라 재현하지 않는다.
 * 그래서 잔액 부족 거절도 없다.
 */
@StubController
@RequestMapping(MarketStubController.BASE_PATH)
public class MarketStubController implements MarketApi {

    static final String BASE_PATH = "/api/v0/market";

    private final ConcertStore concertStore;
    private final ImageStorage imageStorage;
    private final Clock clock;
    private final Map<String, MarketTicket> tickets = new LinkedHashMap<>();

    public MarketStubController(ConcertStore concertStore, ImageStorage imageStorage, Clock clock) {
        this.concertStore = concertStore;
        this.imageStorage = imageStorage;
        this.clock = clock;

        for (MarketTicketFixture fixture : StubFixtures.MARKET_TICKETS) {
            SeatFixture seat = StubFixtures.findSeat(fixture.seatId()).orElseThrow();
            MarketTicket ticket = new MarketTicket(fixture.tokenId(), fixture.concertId(), seat,
                    seat.section().price(), fixture.mine());
            ticket.listPrice = fixture.listPrice();
            ticket.listedAt = fixture.listPrice() == null ? null : StubFixtures.FIXTURE_LISTED_AT;
            tickets.put(ticket.tokenId, ticket);
        }
    }

    @Override
    public synchronized ResponseEntity<ListingResponseDto> list(CreateListingRequestDto request) {
        settle();
        MarketTicket ticket = tickets.get(request.tokenId());
        if (ticket == null) {
            throw new TicketNotFoundException(request.tokenId());
        }
        if (!ticket.mine) {
            throw new NotTicketOwnerException(ticket.tokenId);
        }
        if (ticket.listed()) {
            throw new TicketNotListableException(ticket.tokenId, "이미 등록 중");
        }
        if (request.askPrice() > ticket.facePrice) {
            throw new ListPriceExceedsFacePriceException(request.askPrice(), ticket.facePrice);
        }

        ticket.listPrice = request.askPrice();
        ticket.listedAt = LocalDateTime.now(clock);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/listings/" + ticket.tokenId))
                .body(toListing(ticket));
    }

    @Override
    public synchronized ResponseEntity<Void> delist(String tokenId) {
        MarketTicket ticket = requireListing(tokenId);
        if (!ticket.mine) {
            throw new NotTicketOwnerException(tokenId);
        }
        ticket.listPrice = null;
        ticket.listedAt = null;
        return ResponseEntity.noContent().build();
    }

    @Override
    public synchronized ResponseEntity<PagedModel<ListingResponseDto>> findAll(ListingListRequestDto request) {
        settle();
        List<MarketTicket> matched = tickets.values().stream()
                .filter(MarketTicket::listed)
                .filter(ticket -> request.concertId() == null || ticket.concertId == request.concertId())
                .sorted(Comparator.comparingLong((MarketTicket ticket) -> ticket.listPrice)
                        .thenComparing(Comparator.comparingLong(MarketStubController::tokenIdOf).reversed()))
                .toList();

        Pageable pageable = request.toPageable();
        int from = (int) Math.min(pageable.getOffset(), matched.size());
        int to = Math.min(from + pageable.getPageSize(), matched.size());
        List<ListingResponseDto> content = matched.subList(from, to).stream()
                .map(this::toListing)
                .toList();

        return ResponseEntity.ok(new PagedModel<>(new PageImpl<>(content, pageable, matched.size())));
    }

    @Override
    public synchronized ResponseEntity<PurchaseResponseDto> purchase(String tokenId) {
        MarketTicket ticket = requireListing(tokenId);
        if (ticket.mine) {
            throw new CannotBuyOwnListingException(tokenId);
        }
        if (holdsConcert(ticket.concertId)) {
            throw new AlreadyReservedException(ticket.concertId);
        }

        // 대금 수령 → 소유 이전 → 판매자 정산. 실제라면 Marketplace.buy 한 트랜잭션이다.
        long price = ticket.listPrice;
        LocalDateTime now = LocalDateTime.now(clock);
        String tradeId = StubHashes.of("trade:buy:" + tokenId + ":" + now);
        ticket.mine = true;
        ticket.listPrice = null;
        ticket.listedAt = null;

        ConcertFixture concert = concertOf(ticket);
        return ResponseEntity.ok(new PurchaseResponseDto(
                tradeId,
                StubHashes.of("tx:" + tradeId),
                ticket.tokenId,
                concert.id(),
                concert.title(),
                ticket.seat.section().name(),
                ticket.seat.seatNo(),
                ticket.seat.seatCol(),
                price,
                now));
    }

    private MarketTicket requireListing(String tokenId) {
        settle();
        return Optional.ofNullable(tickets.get(tokenId))
                .filter(MarketTicket::listed)
                .orElseThrow(() -> new ListingNotFoundException(tokenId));
    }

    /**
     * 그 공연의 티켓을 내가 보유 중인가. 온체인 {@code holdsShow} 와 같은 규칙이다.
     *
     * <p>등록 중인 내 매물도 보유로 본다. 팔리기 전까지는 여전히 내 티켓이다. 예매로 확정한 주문은 여기서 보지
     * 않는다. 티켓 도메인이 생기면 그때 함께 판정한다.
     */
    private boolean holdsConcert(long concertId) {
        return tickets.values().stream().anyMatch(ticket -> ticket.mine && ticket.concertId == concertId);
    }

    /** 내 매물 중 팔릴 시각이 지난 것을 남에게 넘긴다. 멱등이라 몇 번 불려도 같다. */
    private void settle() {
        LocalDateTime now = LocalDateTime.now(clock);
        List<MarketTicket> sold = new ArrayList<>();
        for (MarketTicket ticket : tickets.values()) {
            if (ticket.mine && ticket.listed()
                    && !ticket.listedAt.plusSeconds(StubFixtures.LISTING_SOLD_AFTER_SECONDS).isAfter(now)) {
                sold.add(ticket);
            }
        }
        for (MarketTicket ticket : sold) {
            ticket.mine = false;
            ticket.listPrice = null;
            ticket.listedAt = null;
        }
    }

    private ListingResponseDto toListing(MarketTicket ticket) {
        ConcertFixture concert = concertOf(ticket);
        long listPrice = ticket.listPrice;

        return new ListingResponseDto(
                ticket.tokenId,
                concert.id(),
                concert.title(),
                imageStorage.getUrl(concert.posterImageKey()),
                concert.startDate(),
                concert.venueName(),
                ticket.seat.id(),
                ticket.seat.section().id(),
                ticket.seat.section().name(),
                ticket.seat.seatNo(),
                ticket.seat.seatCol(),
                ticket.facePrice,
                listPrice,
                (int) Math.round((ticket.facePrice - listPrice) * 100.0 / ticket.facePrice),
                ticket.mine ? StubFixtures.MY_WALLET_ADDRESS : StubFixtures.OTHER_WALLET_ADDRESS,
                ticket.mine,
                ticket.listedAt);
    }

    private ConcertFixture concertOf(MarketTicket ticket) {
        return concertStore.find(ticket.concertId).orElseThrow();
    }

    /** 동가 매물의 순서를 정하는 유일 키. tokenId 는 uint256 문자열이라 수로 비교한다. */
    private static long tokenIdOf(MarketTicket ticket) {
        return Long.parseLong(ticket.tokenId);
    }

    /**
     * 마켓이 아는 티켓 하나. 소유자와 등록가가 바뀌므로 가변이다.
     *
     * <p>티켓 도메인이 생기면 이 클래스는 사라지고 그쪽 미러 테이블을 읽는다. 그래서 밖으로 노출하지 않는다.
     */
    private static final class MarketTicket {

        private final String tokenId;
        private final long concertId;
        private final SeatFixture seat;
        private final long facePrice;
        private boolean mine;
        private Long listPrice;
        private LocalDateTime listedAt;

        MarketTicket(String tokenId, long concertId, SeatFixture seat, long facePrice, boolean mine) {
            this.tokenId = tokenId;
            this.concertId = concertId;
            this.seat = seat;
            this.facePrice = facePrice;
            this.mine = mine;
        }

        boolean listed() {
            return listPrice != null;
        }
    }
}
