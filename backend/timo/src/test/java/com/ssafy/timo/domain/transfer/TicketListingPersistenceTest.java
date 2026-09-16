package com.ssafy.timo.domain.transfer;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 양도 매물·체결의 유니크 제약이 <b>스키마에 실제로 만들어지는지</b> 실제 MySQL 로 확인한다.
 *
 * <p>이 테스트가 필요한 이유는 {@code SeatHoldPersistenceTest} 와 같다. 이중 등록 판정을
 * {@code uk_listing_ticket_active} 에 맡겼는데, 제약이 만들어지지 않으면 그 판정은 <b>아무 일도
 * 하지 않으면서 조용히 통과</b>한다. 서비스의 선검사만 남아 확인과 저장 사이의 틈이 그대로 열린다.
 *
 * <p>제약의 재료는 {@code status='LISTED'} 일 때만 값을 갖는 생성 칼럼이다. 그래서 여기서 볼 것은
 * "티켓당 매물 하나" 가 아니라 <b>"티켓당 열려 있는 매물 하나"</b> 다 — 취소·체결된 과거 매물까지
 * 걸리면 재양도가 영영 막힌다.
 *
 * <p>통합 테스트가 한 트랜잭션 안에서 도는 탓에 동시 요청은 만들 수 없다. 다만 같은 트랜잭션에서
 * 두 번 넣어도 flush 시점에 같은 판정이 나오므로 제약의 존재는 이렇게 확인된다.
 *
 * <p>{@code saveAndFlush} 를 쓰는 이유도 같다. {@code EntityManager#flush} 를 직접 부르면 스프링의
 * 예외 변환을 거치지 않아 {@code DataIntegrityViolationException} 이 아니라 JPA 의
 * {@code PersistenceException} 이 올라온다. 서비스도 리포지토리를 거치므로 이쪽이 실제 경로다.
 */
@IntegrationTest
class TicketListingPersistenceTest {

    private static final long TICKET_ID = 4242L;
    private static final long OTHER_TICKET_ID = 4343L;
    private static final long PRICE = 90_000L;
    private static final long FACE_VALUE = 100_000L;

    @Autowired
    private TicketListingRepository ticketListingRepository;

    @Autowired
    private TicketTradeRepository ticketTradeRepository;

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
    private EntityManager em;

    private Concert concert;
    private Section section;
    private Member seller;
    private Member buyer;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        concert = saveConcert(venue);
        section = saveSection(venue);
        seller = saveMember("01011112222", "판매자");
        buyer = saveMember("01033334444", "구매자");
        em.flush();
    }

    @Test
    @DisplayName("한 티켓에 열려 있는 매물을 둘 가질 수 없다")
    void uniqueActiveListing_rejectsSecondOpenListing() {
        ticketListingRepository.save(listing(TICKET_ID, PRICE));
        em.flush();

        assertThatThrownBy(() -> ticketListingRepository.saveAndFlush(listing(TICKET_ID, PRICE - 1)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("취소된 매물은 제약에서 빠져 같은 티켓을 다시 등록할 수 있다")
    void uniqueActiveListing_ignoresCanceled() {
        TicketListing first = ticketListingRepository.save(listing(TICKET_ID, PRICE));
        em.flush();

        ticketListingRepository.markCanceledIfListed(first.getId(), LocalDateTime.now());

        assertThatCode(() -> ticketListingRepository.saveAndFlush(listing(TICKET_ID, PRICE)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("체결된 매물도 제약에서 빠진다 - 산 사람이 재양도할 수 있어야 한다")
    void uniqueActiveListing_ignoresSold() {
        TicketListing first = ticketListingRepository.save(listing(TICKET_ID, PRICE));
        em.flush();

        ticketListingRepository.markSoldIfListed(first.getId(), LocalDateTime.now());

        assertThatCode(() -> ticketListingRepository.saveAndFlush(listing(TICKET_ID, PRICE)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("티켓이 다르면 매물이 함께 열려 있을 수 있다")
    void uniqueActiveListing_isScopedToTicket() {
        ticketListingRepository.save(listing(TICKET_ID, PRICE));
        em.flush();

        assertThatCode(() -> ticketListingRepository.saveAndFlush(listing(OTHER_TICKET_ID, PRICE)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("매물 하나에 체결은 하나뿐이다 - 이중 체결의 마지막 방어선")
    void uniqueTrade_rejectsSecondTradeOnSameListing() {
        TicketListing listing = ticketListingRepository.save(listing(TICKET_ID, PRICE));
        em.flush();

        ticketTradeRepository.save(TicketTrade.record(listing, buyer.getId(), LocalDateTime.now()));
        em.flush();

        assertThatThrownBy(() -> ticketTradeRepository.saveAndFlush(
                TicketTrade.record(listing, buyer.getId(), LocalDateTime.now())))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("조건부 UPDATE 는 LISTED 일 때만 먹는다 - 두 번째 호출은 영향 행이 0 이다")
    void conditionalUpdate_appliesOnlyOnce() {
        TicketListing listing = ticketListingRepository.save(listing(TICKET_ID, PRICE));
        em.flush();

        LocalDateTime now = LocalDateTime.now();
        assertThat(ticketListingRepository.markSoldIfListed(listing.getId(), now)).isEqualTo(1);
        assertThat(ticketListingRepository.markSoldIfListed(listing.getId(), now)).isZero();
        assertThat(ticketListingRepository.markCanceledIfListed(listing.getId(), now)).isZero();
    }

    // ---------------------------------------------------------------- 헬퍼

    private TicketListing listing(long ticketId, long price) {
        return TicketListing.open(ticketId, seller.getId(), concert, section,
                1, 1, price, FACE_VALUE, LocalDateTime.now());
    }

    private Concert saveConcert(Venue venue) {
        return concertRepository.save(Concert.builder()
                .title("9월 20일 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(20))
                .endDate(LocalDateTime.now().plusDays(20).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(10))
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
        List<SeatPosition> positions = IntStream.rangeClosed(1, 2)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();

        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(150000)
                .rowCount(2)
                .seatPerRow(2)
                .venue(venue)
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
