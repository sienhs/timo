package com.ssafy.timo.domain.reservation;

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
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;
import java.util.stream.IntStream;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 예매 목록 응답이 {@code ticketId} 를 싣는지 본다.
 *
 * <p><b>이것만 보는 테스트다.</b> 예매 API 전체를 덮는 통합 테스트는 아직 없고 이번 작업에서도
 * 만들지 않는다. 그런데도 이 한 건을 두는 이유는, 목록의 {@code ticketId} 가 다른 필드들과 달리
 * <b>주문 행에서 바로 나오지 않기 때문이다</b> - {@code Reservation} 은 티켓을 가리키지 않아
 * ({@code Ticket -> Reservation} 단방향) 목록 조회가 페이지를 읽은 뒤 티켓을 따로 모아 와서
 * 주문 번호로 맞춰 넣는다({@code ReservationServiceImpl.ticketIdsOf}).
 *
 * <p>그 맞춰 넣기가 어긋나면 <b>조용히 틀린다</b> - 전부 {@code null} 이 되거나, 더 나쁘게는 남의
 * 티켓 번호가 실린다. 컴파일도 되고 다른 테스트도 통과한다. 양도 등록이 이 값을 그대로 믿고
 * 쓰므로 여기서 한 번은 확인해야 한다.
 *
 * <p>그래서 주문을 <b>두 건</b> 만든다. 한 건이면 짝이 뒤바뀌어도 우연히 맞는다.
 */
@IntegrationTest
class ReservationTicketIdIntegrationTest {

    private static final String RESERVATIONS_PATH = "/api/v1/reservations";
    private static final int SEAT_PRICE = 100_000;

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
    private EntityManager em;

    private Member member;
    private Ticket firstTicket;
    private Ticket secondTicket;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        Section section = saveSection(venue);
        List<Seat> seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());

        member = memberRepository.save(Member.builder()
                .phoneNumber("01011112222")
                .name("전재민")
                .nickname("예매자")
                .build());

        // 공연을 둘로 나눈다. "한 계정 한 공연 1매" 라 같은 공연에 두 번 예매할 수 없다.
        firstTicket = saveTicket(saveConcert(venue, "아이유 콘서트", 20), seats.get(0));
        secondTicket = saveTicket(saveConcert(venue, "김필 단독 콘서트", 25), seats.get(1));

        em.flush();
        Authenticated.set(member.getId());
    }

    @AfterEach
    void clearRequester() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("목록의 각 항목에 그 주문의 티켓 번호가 실린다 - 주문 번호와 다른 값이다")
    void listCarriesTicketId() throws Exception {
        long firstReservationId = firstTicket.getReservation().getId();
        long secondReservationId = secondTicket.getReservation().getId();

        mvc.perform(get(RESERVATIONS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                // 주문마다 자기 티켓이 붙어야 한다. 짝이 뒤바뀌면 여기서 걸린다.
                .andExpect(jsonPath("$.content[?(@.id == %d)].ticketId".formatted(firstReservationId))
                        .value(firstTicket.getId().intValue()))
                .andExpect(jsonPath("$.content[?(@.id == %d)].ticketId".formatted(secondReservationId))
                        .value(secondTicket.getId().intValue()));
    }

    /** 주문과 티켓을 함께 만든다. 실제 경로({@code ReservationServiceImpl.create})도 같은 트랜잭션에서 둘을 만든다. */
    private Ticket saveTicket(Concert concert, Seat seat) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(member)
                .seat(seat)
                .build());

        return ticketRepository.save(Ticket.builder()
                .reservation(reservation)
                .build());
    }

    private Concert saveConcert(Venue venue, String title, int daysLater) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(java.time.LocalDateTime.now().plusDays(daysLater))
                .endDate(java.time.LocalDateTime.now().plusDays(daysLater).plusHours(3))
                .openAt(java.time.LocalDateTime.now().plusDays(1))
                .venue(venue)
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
                .price(SEAT_PRICE)
                .rowCount(3)
                .seatPerRow(2)
                .venue(venue)
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
