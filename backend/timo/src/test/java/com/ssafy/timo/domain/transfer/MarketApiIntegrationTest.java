package com.ssafy.timo.domain.transfer;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import com.ssafy.timo.support.MarketClock;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.endsWith;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.notNullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 양도 마켓 API(v1) 통합 테스트.
 *
 * <p>스텁({@code /api/v0/market})이 아니라 <b>실제 DB 를 태우는 v1</b> 을 본다. 여기서만 확인되는
 * 것이 두 가지다.
 *
 * <ul>
 *   <li>내 거래 내역의 <b>네이티브 {@code UNION ALL} 쿼리</b> — JPQL 과 달리 기동 시점에 검증되지
 *       않아, 실제로 호출해 봐야 컬럼명·별칭이 맞는지 알 수 있다</li>
 *   <li>응답에 <b>{@code ticketId} 와 {@code tokenId}, 판매자 식별자가 새지 않는지</b> —
 *       DTO 를 눈으로 확인하는 것과 실제 JSON 을 보는 것은 다르다. 좌석번호는 2026-09-16 부터
 *       공개 대상이라 반대로 <b>나오는지</b>를 본다</li>
 * </ul>
 *
 * <p>요청자는 {@link Authenticated} 가 홀더에 직접 넣는다. {@code addFilters = false} 라 필터가
 * 인증 객체를 만들어 주지 않기 때문이다. 매물이 회원 id 를 들고 있어 아무 숫자나 쓸 수는 없고
 * 실제로 저장한 회원 id 를 쓴다.
 *
 * <p><b>에러 응답은 {@code errorCode} 가 아니라 {@code exception} 으로 단언한다.</b> 도메인
 * 예외의 응답에는 {@code errorCode} 가 실리지 않는다 - {@code GlobalExceptionHandler} 는
 * {@code errorMessage} · {@code timestamp} · {@code exception} 만 넣고, {@code errorCode} 를 넣는 것은
 * 인증 필터 쪽({@code AuthExceptionHandler}) 하나뿐이다. <b>API 규약 문서는 모든 에러에
 * {@code errorCode} 가 내려간다고 적고 있어 실제와 어긋난다</b> - 이 테스트는 실제 동작을 적는다.
 *
 * <p><b>동시 구매·롤백은 여기서 검증할 수 없다.</b> 테스트 전체가 한 트랜잭션이라 두 요청을 겹치게
 * 만들 수 없고, 예외가 나도 그 트랜잭션 안에서는 조건부 UPDATE 가 되돌아간 것처럼 보이지 않는다.
 * 제약이 스키마에 실제로 걸려 있는지는 {@link TicketListingPersistenceTest} 가 본다.
 */
@IntegrationTest
class MarketApiIntegrationTest {

    private static final String MARKET_PATH = "/api/v1/market";
    private static final long FACE_PRICE = 100_000L;
    private static final long LIST_PRICE = 90_000L;

    @Autowired
    private MockMvc mvc;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private TicketRepository ticketRepository;

    @Autowired
    private TicketListingRepository ticketListingRepository;

    @Autowired
    private TicketTradeRepository ticketTradeRepository;

    @Autowired
    private EntityManager em;

    /** 운영 시간 판정용 시계. 기본은 열림(21:00)이고, 닫는 테스트는 끝나기 전에 되돌린다. */
    @Autowired
    private MarketClock marketClock;

    private Concert concert;
    private Section section;
    private Member seller;
    private Member buyer;
    private Ticket myTicket;
    private Ticket othersTicket;
    private Ticket unmintedTicket;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        section = saveSection(venue);
        List<Seat> seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());

        seller = saveMember("01011112222", "판매자");
        buyer = saveMember("01033334444", "구매자");

        concert = saveConcert(venue, "아이유 콘서트", 20);
        // 정가가 없으면 등록이 성립하지 않는다. 예매 결제·환불이 이 값으로 이루어진다.
        concert.prepareForSale(seller);

        myTicket = saveOwnedTicket(concert, seats.get(0), seller);
        othersTicket = saveOwnedTicket(concert, seats.get(1), buyer);
        unmintedTicket = ticketRepository.save(Ticket.builder()
                .reservation(saveReservation(saveConcert(venue, "다른 공연", 25), seats.get(2), seller))
                .build());

        em.flush();
        Authenticated.set(seller.getId());
    }

    @AfterEach
    void clearRequester() {
        Authenticated.clear();
        marketClock.open();
    }

    @Nested
    @DisplayName("운영 시간")
    class Hours {

        @Test
        @DisplayName("열려 있으면 open 이고 오늘 창의 시각을 준다")
        void hoursWhileOpen() throws Exception {
            mvc.perform(get(MARKET_PATH + "/hours"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.open").value(true))
                    .andExpect(jsonPath("$.serverTime").value(endsWith("T21:00:00")))
                    .andExpect(jsonPath("$.opensAt").value(endsWith("T08:00:00")))
                    .andExpect(jsonPath("$.closesAt").value(endsWith("T23:00:00")));
        }

        @Test
        @DisplayName("닫혀 있으면 closed 이고 다음 창의 시각을 준다")
        void hoursWhileClosed() throws Exception {
            marketClock.closed();

            mvc.perform(get(MARKET_PATH + "/hours"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.open").value(false))
                    .andExpect(jsonPath("$.opensAt").value(endsWith("T08:00:00")));
        }

        @Test
        @DisplayName("닫힌 시간에도 등록은 201 - 매물은 저장되지만 오늘 창에는 나오지 않는다")
        void registerWhileClosed() throws Exception {
            marketClock.closed();

            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(myTicket.getId(), LIST_PRICE)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.status").value("LISTED"));

            // 닫힌 동안은 목록 자체가 막히고, 열려도 오늘 등록한 매물은 다음 날 08:00 까지 안 보인다.
            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("MarketClosedException"));
            marketClock.open();
            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.page.totalElements").value(0));
        }

        @Test
        @DisplayName("어제 등록한 매물은 보이고 오늘 등록한 매물은 보이지 않는다 - 등록 다음 날 08:00 노출")
        void listingsBecomeVisibleTheDayAfter() throws Exception {
            TicketListing yesterday = openListingAt(othersTicket, LIST_PRICE, LocalDateTime.now().minusDays(1));
            TicketListing today = openListingAt(myTicket, LIST_PRICE - 10_000, LocalDateTime.now());

            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.page.totalElements").value(1))
                    .andExpect(jsonPath("$.content[0].listingId").value(yesterday.getId()));
            // 공연 목록의 매물 수와 최저가도 어제 것만 센다. 오늘 것이 더 싸지만 잡히면 안 된다.
            mvc.perform(get(MARKET_PATH + "/concerts"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content[0].listingCount").value(1))
                    .andExpect(jsonPath("$.content[0].lowestPrice").value(LIST_PRICE));
            // 번호를 알아도 오늘 등록된 매물은 살 수 없다. 상세는 판매자 경로라 열려 있다.
            Authenticated.set(buyer.getId());
            purchase(today, LIST_PRICE - 10_000)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingNotOpenYetException"));
            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", today.getId()))
                    .andExpect(status().isOk());
        }

        @Test
        @DisplayName("닫힌 시간에는 공연 목록과 구매가 409 - 등록된 매물이 있어도 보이지 않는다")
        void browseAndPurchaseAreClosed() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);
            marketClock.closed();

            mvc.perform(get(MARKET_PATH + "/concerts"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("MarketClosedException"));
            purchase(othersListing, LIST_PRICE)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("MarketClosedException"));
        }

        @Test
        @DisplayName("닫힌 시간에도 상세, 내 내역, 취소는 된다 - 판매자가 자기 매물을 다루는 경로다")
        void sellerPathsStayOpenWhileClosed() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);
            marketClock.closed();

            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", listing.getId()))
                    .andExpect(status().isOk());
            mvc.perform(get(MARKET_PATH + "/listings/me"))
                    .andExpect(status().isOk());
            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", listing.getId()))
                    .andExpect(status().isNoContent());
        }
    }

    @Nested
    @DisplayName("등록")
    class Register {

        @Test
        @DisplayName("내 티켓을 정가 이하로 등록하면 201 이고 티켓 식별자는 응답에 없다")
        void register() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(myTicket.getId(), LIST_PRICE)))
                    .andExpect(status().isCreated())
                    .andExpect(header().exists("Location"))
                    .andExpect(jsonPath("$.status").value("LISTED"))
                    .andExpect(jsonPath("$.price").value(LIST_PRICE))
                    .andExpect(jsonPath("$.faceValue").value(FACE_PRICE))
                    .andExpect(jsonPath("$.discountRate").value(10))
                    .andExpect(jsonPath("$.mine").value(true))
                    .andExpect(jsonPath("$.closedAt").doesNotExist())
                    // 좌석번호는 공개한다. 구매자가 자리를 보고 골라야 하기 때문이다.
                    .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                    .andExpect(jsonPath("$.seatNo").value(myTicket.getReservation().getSeat().getSeatNo()))
                    .andExpect(jsonPath("$.seatCol").value(myTicket.getReservation().getSeat().getSeatCol()))
                    // 노출 경계 - 판매자와 티켓 식별자는 그대로 비공개다.
                    .andExpect(jsonPath("$.ticketId").doesNotExist())
                    .andExpect(jsonPath("$.tokenId").doesNotExist())
                    .andExpect(jsonPath("$.sellerMemberId").doesNotExist());
        }

        @Test
        @DisplayName("없는 티켓이면 404")
        void notFound() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(99_999L, LIST_PRICE)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("TicketNotFoundException"));
        }

        @Test
        @DisplayName("남의 티켓이면 403")
        void notOwner() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(othersTicket.getId(), LIST_PRICE)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotTicketOwnerException"));
        }

        @Test
        @DisplayName("아직 발행되지 않은 티켓이면 409 - tokenId 가 없어 올릴 대상이 없다")
        void notMinted() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(unmintedTicket.getId(), LIST_PRICE)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("TicketNotListableException"));
        }

        @Test
        @DisplayName("정가를 넘기면 400 - 정가 초과 판매 차단이 이 서비스의 존재 이유다")
        void exceedsFacePrice() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(myTicket.getId(), FACE_PRICE + 1)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("ListPriceExceedsFacePriceException"));
        }

        @Test
        @DisplayName("정가와 같으면 등록된다 - 이하까지 허용이다")
        void samePriceAsFaceValue() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(myTicket.getId(), FACE_PRICE)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.discountRate").value(0));
        }

        @Test
        @DisplayName("이미 등록 중인 티켓이면 409")
        void alreadyListed() throws Exception {
            openListing(myTicket, LIST_PRICE);

            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(myTicket.getId(), LIST_PRICE)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("TicketNotListableException"));
        }

        @Test
        @DisplayName("등록가가 0 이하면 400 - 무상 전송은 성립하지 않는다")
        void nonPositivePrice() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body(myTicket.getId(), 0)))
                    .andExpect(status().isBadRequest());
        }
    }

    @Nested
    @DisplayName("조회")
    class Query {

        @Test
        @DisplayName("매물이 있는 공연만 나오고 매물 수와 최저가가 집계된다")
        void findConcerts() throws Exception {
            openListing(myTicket, LIST_PRICE);
            openListing(othersTicket, LIST_PRICE - 10_000);

            mvc.perform(get(MARKET_PATH + "/concerts"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content[?(@.concertId == %d)].listingCount".formatted(concert.getId()),
                            contains(2)))
                    .andExpect(jsonPath("$.content[?(@.concertId == %d)].lowestPrice".formatted(concert.getId()),
                            contains((int) LIST_PRICE - 10_000)))
                    .andExpect(jsonPath("$.content[0].listingId").doesNotExist());
        }

        @Test
        @DisplayName("공연별 매물은 낮은 가격순이고 내 것은 mine 으로 구분된다")
        void findListings() throws Exception {
            openListing(myTicket, LIST_PRICE);
            openListing(othersTicket, LIST_PRICE - 10_000);

            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content.length()").value(2))
                    .andExpect(jsonPath("$.content[0].price").value(LIST_PRICE - 10_000))
                    .andExpect(jsonPath("$.content[1].price").value(LIST_PRICE))
                    .andExpect(jsonPath("$.content[1].mine").value(true))
                    .andExpect(jsonPath("$.content[0].mine").value(false))
                    // 목록에서도 좌석번호를 준다.
                    .andExpect(jsonPath("$.content[0].seatNo").exists())
                    .andExpect(jsonPath("$.content[0].seatCol").exists())
                    .andExpect(jsonPath("$.content[0].ticketId").doesNotExist());
        }

        @Test
        @DisplayName("없는 공연이면 404, 공연이 있고 매물만 없으면 빈 목록으로 200")
        void findListingsOfMissingConcert() throws Exception {
            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", 99_999L))
                    .andExpect(status().isNotFound());

            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content.length()").value(0));
        }

        @Test
        @DisplayName("팔린 매물도 상세는 200 - 목록에서 들어오는 사이에 팔릴 수 있다")
        void findSoldListing() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);
            ticketListingRepository.markSoldIfListed(listing.getId(), LocalDateTime.now());

            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", listing.getId()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("SOLD"))
                    .andExpect(jsonPath("$.closedAt").exists());
        }

        @Test
        @DisplayName("없는 매물이면 404")
        void findMissingListing() throws Exception {
            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", 99_999L))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));
        }
    }

    @Nested
    @DisplayName("내 거래 내역")
    class MyTrades {

        @Test
        @DisplayName("판매와 구매가 한 목록에 섞여 최신순으로 나온다")
        void findMyTrades() throws Exception {
            openListing(myTicket, LIST_PRICE);

            // 남의 매물을 내가 산다 - PURCHASE 항목이 되어야 한다.
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);
            purchase(othersListing, LIST_PRICE).andExpect(status().isAccepted());

            mvc.perform(get(MARKET_PATH + "/listings/me"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content.length()").value(2))
                    .andExpect(jsonPath("$.content[*].type", containsInAnyOrder("SALE", "PURCHASE")))
                    .andExpect(jsonPath("$.content[?(@.type == 'SALE')].status", contains("LISTED")))
                    .andExpect(jsonPath("$.content[?(@.type == 'PURCHASE')].status", contains("PENDING")))
                    .andExpect(jsonPath("$.content[?(@.type == 'SALE')].tradeId", contains((Object) null)))
                    .andExpect(jsonPath("$.content[*].seatNo", everyItem(notNullValue())))
                    // 거래 상대도 티켓 식별자도 드러나지 않는다.
                    .andExpect(jsonPath("$.content[0].ticketId").doesNotExist())
                    .andExpect(jsonPath("$.content[0].sellerMemberId").doesNotExist())
                    .andExpect(jsonPath("$.content[0].buyerMemberId").doesNotExist());
        }

        @Test
        @DisplayName("거래가 없으면 빈 목록이다")
        void empty() throws Exception {
            mvc.perform(get(MARKET_PATH + "/listings/me"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content.length()").value(0));
        }
    }

    @Nested
    @DisplayName("가격 수정")
    class UpdatePrice {

        /** 가격 수정은 운영 시간 밖에서만 된다. 이 묶음은 닫힌 마켓에서 돌리고, 목록을 볼 때만 연다. */
        @BeforeEach
        void closeMarket() {
            marketClock.closed();
        }

        @Test
        @DisplayName("운영 시간 중에는 409 - 거래가 열려 있는 동안 가격은 고정이다")
        void rejectedWhileOpen() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);
            marketClock.open();

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(80_000)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("MarketOpenException"));
            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", listing.getId()))
                    .andExpect(jsonPath("$.price").value(LIST_PRICE));
        }

        @Test
        @DisplayName("내 매물 가격을 내리면 200 이고 목록·상세·할인율에 함께 반영된다")
        void updatePrice() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(80_000)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.listingId").value(listing.getId()))
                    .andExpect(jsonPath("$.status").value("LISTED"))
                    .andExpect(jsonPath("$.price").value(80_000))
                    // 정가는 등록 시점 스냅샷이라 가격을 고쳐도 움직이지 않는다.
                    .andExpect(jsonPath("$.faceValue").value(FACE_PRICE))
                    .andExpect(jsonPath("$.discountRate").value(20))
                    .andExpect(jsonPath("$.mine").value(true))
                    // 노출 경계는 상세와 같다.
                    .andExpect(jsonPath("$.ticketId").doesNotExist())
                    .andExpect(jsonPath("$.sellerMemberId").doesNotExist());

            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", listing.getId()))
                    .andExpect(jsonPath("$.price").value(80_000));
            // 목록은 열려야 보인다. 마감 뒤에 바꾼 가격이 다음 창에 그대로 올라가는지가 여기다.
            marketClock.open();
            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(jsonPath("$.content[0].price").value(80_000));
        }

        @Test
        @DisplayName("올리는 것도 정가 이하면 된다 - 방향이 아니라 상한만 본다")
        void raisePrice() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(FACE_PRICE)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.price").value(FACE_PRICE))
                    .andExpect(jsonPath("$.discountRate").value(0));
        }

        @Test
        @DisplayName("같은 가격을 다시 보내도 200 - 재시도가 안전해야 한다")
        void samePriceIsIdempotent() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(LIST_PRICE)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.price").value(LIST_PRICE));
        }

        @Test
        @DisplayName("정가를 넘기면 400 - 등록과 같은 규칙이다")
        void exceedsFacePrice() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(FACE_PRICE + 1)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("ListPriceExceedsFacePriceException"));

            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", listing.getId()))
                    .andExpect(jsonPath("$.price").value(LIST_PRICE));
        }

        @Test
        @DisplayName("남의 매물은 고칠 수 없다 - 403")
        void notSeller() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", othersListing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(10_000)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotListingSellerException"));
        }

        @Test
        @DisplayName("이미 종료된 매물이면 409")
        void alreadyClosed() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", listing.getId()))
                    .andExpect(status().isNoContent());

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(80_000)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingAlreadyClosedException"));
        }

        @Test
        @DisplayName("없는 매물이면 404")
        void notFound() throws Exception {
            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", 99_999L)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(80_000)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));
        }

        @Test
        @DisplayName("0 이하면 400 - 무상 전송은 성립하지 않는다")
        void nonPositivePrice() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(patch(MARKET_PATH + "/listings/{listingId}/price", listing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(priceBody(0)))
                    .andExpect(status().isBadRequest());
        }
    }

    @Nested
    @DisplayName("취소")
    class Cancel {

        @Test
        @DisplayName("내 매물을 취소하면 204 이고 목록에서 빠진다")
        void cancel() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", listing.getId()))
                    .andExpect(status().isNoContent());

            mvc.perform(get(MARKET_PATH + "/concerts/{concertId}/listings", concert.getId()))
                    .andExpect(jsonPath("$.content.length()").value(0));
            mvc.perform(get(MARKET_PATH + "/listings/{listingId}", listing.getId()))
                    .andExpect(jsonPath("$.status").value("CANCELED"));
        }

        @Test
        @DisplayName("이미 취소된 매물을 또 취소하면 409")
        void cancelTwice() throws Exception {
            TicketListing listing = openListing(myTicket, LIST_PRICE);

            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", listing.getId()))
                    .andExpect(status().isNoContent());
            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", listing.getId()))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingAlreadyClosedException"));
        }

        @Test
        @DisplayName("남의 매물은 취소할 수 없다 - 403")
        void cancelOthers() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);

            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", othersListing.getId()))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotListingSellerException"));
        }

        @Test
        @DisplayName("없는 매물이면 404")
        void cancelMissing() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/cancel", 99_999L))
                    .andExpect(status().isNotFound());
        }
    }

    @Nested
    @DisplayName("체결")
    class Purchase {

        @Test
        @DisplayName("매물을 사면 202 이고 거래는 PENDING 이다 - 온체인이 남아 있다")
        void purchaseListing() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);

            purchase(othersListing, LIST_PRICE)
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.status").value("PENDING"))
                    .andExpect(jsonPath("$.price").value(LIST_PRICE))
                    .andExpect(jsonPath("$.tradeId").exists())
                    .andExpect(jsonPath("$.seatNo").value(othersTicket.getReservation().getSeat().getSeatNo()))
                    .andExpect(jsonPath("$.seatCol").value(othersTicket.getReservation().getSeat().getSeatCol()))
                    .andExpect(jsonPath("$.txHash").doesNotExist())
                    .andExpect(jsonPath("$.ticketId").doesNotExist());
        }

        @Test
        @DisplayName("이미 팔린 매물이면 409 - 선착순에서 진 쪽이 받는 응답")
        void alreadySold() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);
            ticketListingRepository.markSoldIfListed(othersListing.getId(), LocalDateTime.now());

            purchase(othersListing, LIST_PRICE)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingAlreadyClosedException"));
        }

        @Test
        @DisplayName("매물은 LISTED 인데 티켓이 회수됐으면 409 - 예매 취소 가드가 뚫려도 여기서 한 번 더 막는다")
        void ticketNoLongerOwned() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);
            othersTicket.revoke();
            em.flush();

            purchase(othersListing, LIST_PRICE)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingAlreadyClosedException"))
                    .andExpect(jsonPath("$.errorMessage").value(containsString("REVOKED")));

            em.clear();
            // 거절이 조건부 UPDATE 를 되돌려 매물은 LISTED 로 남는다. 한 트랜잭션이라 여기서는 보이지 않으므로
            // 거래 행이 없는 것으로 대신 확인한다.
            assertThat(ticketTradeRepository.existsByListingId(othersListing.getId())).isFalse();
        }

        @Test
        @DisplayName("화면에서 본 가격과 다르면 409")
        void priceMismatch() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);

            purchase(othersListing, LIST_PRICE - 1)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingPriceMismatchException"));
        }

        @Test
        @DisplayName("내가 올린 매물은 살 수 없다 - 409")
        void cannotBuyOwn() throws Exception {
            TicketListing mine = openListing(myTicket, LIST_PRICE);

            purchase(mine, LIST_PRICE)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("CannotBuyOwnListingException"));
        }

        @Test
        @DisplayName("없는 매물이면 404 - '방금 팔린 매물' 과 구분된다")
        void missingListing() throws Exception {
            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/purchase", 99_999L)
                            .header("Idempotency-Key", "key-1")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"expectedPrice\": %d}".formatted(LIST_PRICE)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));
        }

        @Test
        @DisplayName("멱등키 헤더가 없으면 400 - 규약상 필수다")
        void missingIdempotencyKey() throws Exception {
            TicketListing othersListing = openListing(othersTicket, LIST_PRICE);

            mvc.perform(post(MARKET_PATH + "/listings/{listingId}/purchase", othersListing.getId())
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"expectedPrice\": %d}".formatted(LIST_PRICE)))
                    .andExpect(status().isBadRequest());
        }
    }

    // ---------------------------------------------------------------- 헬퍼

    private org.springframework.test.web.servlet.ResultActions purchase(TicketListing listing, long expectedPrice)
            throws Exception {
        return mvc.perform(post(MARKET_PATH + "/listings/{listingId}/purchase", listing.getId())
                .header("Idempotency-Key", "key-" + listing.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"expectedPrice\": %d}".formatted(expectedPrice)));
    }

    private String priceBody(long price) {
        return """
                {"price": %d}
                """.formatted(price);
    }

    private String body(long ticketId, long price) {
        return """
                {"ticketId": %d, "price": %d}
                """.formatted(ticketId, price);
    }

    /** 서비스를 거치지 않고 <b>어제</b> 등록된 매물을 연다. 오늘 등록된 매물은 목록과 구매에서 아직 보이지 않는다. */
    private TicketListing openListing(Ticket ticket, long price) {
        return openListingAt(ticket, price, LocalDateTime.now().minusDays(1));
    }

    private TicketListing openListingAt(Ticket ticket, long price, LocalDateTime listedAt) {
        TicketListing listing = ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(),
                ticket.getReservation().getMember().getId(),
                ticket.getReservation().getConcert(),
                ticket.getReservation().getSeat().getSection(),
                ticket.getReservation().getSeat().getSeatNo(),
                ticket.getReservation().getSeat().getSeatCol(),
                price,
                FACE_PRICE,
                listedAt));
        em.flush();
        return listing;
    }

    private Ticket saveOwnedTicket(Concert forConcert, Seat seat, Member owner) {
        Ticket ticket = ticketRepository.save(Ticket.builder()
                .reservation(saveReservation(forConcert, seat, owner))
                .build());
        // 발행이 끝난 티켓만 양도할 수 있다.
        ticket.markMinted(BigInteger.valueOf(seat.getId()), "0x" + "1".repeat(64));
        return ticket;
    }

    private Reservation saveReservation(Concert forConcert, Seat seat, Member member) {
        return reservationRepository.save(Reservation.builder()
                .concert(forConcert)
                .member(member)
                .seat(seat)
                .build());
    }

    private Concert saveConcert(Venue venue, String title, int daysLater) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(daysLater))
                .endDate(LocalDateTime.now().plusDays(daysLater).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build());
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name("전재민")
                .nickname(nickname)
                .build());
    }

    private Section saveSection(Venue venue) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, 3)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();

        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price((int) FACE_PRICE)
                .rowCount(3)
                .seatPerRow(2)
                .venue(venue)
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
