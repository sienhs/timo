package com.ssafy.timo.domain.seat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
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

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 선점·주문의 유니크 제약이 <b>스키마에 실제로 만들어지는지</b> 실제 MySQL 로 확인한다.
 *
 * <p>이 테스트가 이 자리에 있는 이유가 있다. 동시 선점 판정을 좌석 행 잠금에서 유니크 충돌로 바꿨는데,
 * 제약이 만들어지지 않으면 그 판정은 <b>아무 일도 하지 않으면서 조용히 통과</b>한다. 통합 테스트는 한
 * 트랜잭션 안에서 돌아 동시 요청을 만들 수 없으므로, 제약 자체가 걸려 있는지는 여기서 못 박는다.
 *
 * <p>핵심은 "유효한 행만 유일하다" 는 것이다. 끝난 선점과 취소된 주문까지 제약에 걸리면 같은 자리를
 * 다시 팔 수 없다. 그래서 {@code status} 가 살아 있을 때만 값을 갖는 생성 칼럼에 제약을 건다.
 * 동시성이 없어도 같은 트랜잭션에서 두 번 넣으면 flush 시점에 같은 판정이 나온다.
 *
 * <p>위반을 확인할 때 {@code EntityManager#flush} 를 직접 부르지 않고 리포지토리의
 * {@code saveAndFlush} 를 쓴다. 스프링의 예외 변환은 리포지토리 프록시에 걸려 있어서, 직접 부르면
 * {@code DataIntegrityViolationException} 이 아니라 JPA 의 {@code PersistenceException} 이 올라온다.
 * 서비스도 리포지토리를 거치므로 이쪽이 실제 경로와도 같다.
 */
@IntegrationTest
class SeatHoldPersistenceTest {

    @Autowired
    private SeatHoldRepository seatHoldRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private EntityManager em;

    private Concert concertA;
    private Concert concertB;
    private Member me;
    private Member someoneElse;
    private Seat seatOne;
    private Seat seatTwo;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());

        concertA = saveConcert(venue, "9월 20일 공연");
        concertB = saveConcert(venue, "9월 21일 공연");

        me = saveMember("01011112222", "나");
        someoneElse = saveMember("01033334444", "남");

        Section section = saveSection(venue);
        List<Seat> seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
        seatOne = seats.get(0);
        seatTwo = seats.get(1);
        em.flush();
    }

    // ---------------------------------------------------------------- seat_hold

    @Test
    @DisplayName("같은 공연의 같은 좌석은 유효한 선점을 둘 가질 수 없다")
    void uniqueHoldSeat_rejectsSecondActiveHoldOnSameSeat() {
        seatHoldRepository.save(hold(concertA, seatOne, me));
        em.flush();

        assertThatThrownBy(() -> seatHoldRepository.saveAndFlush(hold(concertA, seatOne, someoneElse)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("끝난 선점은 제약에서 빠져 같은 자리를 다시 잡을 수 있다")
    void uniqueHoldSeat_ignoresFinishedHolds() {
        SeatHold first = seatHoldRepository.save(hold(concertA, seatOne, me));
        em.flush();

        first.release(LocalDateTime.now());
        em.flush();

        assertThatCode(() -> {
            seatHoldRepository.save(hold(concertA, seatOne, someoneElse));
            em.flush();
        }).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("공연이 다르면 같은 좌석을 동시에 잡을 수 있다")
    void uniqueHoldSeat_isScopedToConcert() {
        seatHoldRepository.save(hold(concertA, seatOne, me));
        em.flush();

        assertThatCode(() -> {
            seatHoldRepository.save(hold(concertB, seatOne, someoneElse));
            em.flush();
        }).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("한 회원은 한 공연에서 좌석을 둘 잡을 수 없다")
    void uniqueHoldMember_rejectsSecondSeatInSameConcert() {
        seatHoldRepository.save(hold(concertA, seatOne, me));
        em.flush();

        assertThatThrownBy(() -> seatHoldRepository.saveAndFlush(hold(concertA, seatTwo, me)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("공연이 다르면 한 회원이 좌석을 각각 잡을 수 있다")
    void uniqueHoldMember_isScopedToConcert() {
        seatHoldRepository.save(hold(concertA, seatOne, me));
        em.flush();

        assertThatCode(() -> {
            seatHoldRepository.save(hold(concertB, seatTwo, me));
            em.flush();
        }).doesNotThrowAnyException();
    }

    // ---------------------------------------------------------------- reservation

    @Test
    @DisplayName("같은 공연의 같은 좌석은 유효한 주문을 둘 가질 수 없다")
    void uniqueReservationSeat_rejectsDoubleSale() {
        reservationRepository.save(reservation(concertA, seatOne, me));
        em.flush();

        assertThatThrownBy(() -> reservationRepository.saveAndFlush(reservation(concertA, seatOne, someoneElse)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("취소된 주문은 제약에서 빠져 같은 자리를 다시 팔 수 있다")
    void uniqueReservationSeat_ignoresCancelled() {
        Reservation first = reservationRepository.save(reservation(concertA, seatOne, me));
        em.flush();

        first.cancel(LocalDateTime.now());
        em.flush();

        assertThatCode(() -> {
            reservationRepository.save(reservation(concertA, seatOne, someoneElse));
            em.flush();
        }).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("한 회원은 한 공연에서 두 장을 살 수 없다")
    void uniqueReservationMember_enforcesOneTicketPerConcert() {
        reservationRepository.save(reservation(concertA, seatOne, me));
        em.flush();

        assertThatThrownBy(() -> reservationRepository.saveAndFlush(reservation(concertA, seatTwo, me)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("공연이 다르면 한 회원이 각각 한 장씩 살 수 있다")
    void uniqueReservationMember_isScopedToConcert() {
        reservationRepository.save(reservation(concertA, seatOne, me));
        em.flush();

        assertThatCode(() -> {
            reservationRepository.save(reservation(concertB, seatOne, me));
            em.flush();
        }).doesNotThrowAnyException();
    }

    // ---------------------------------------------------------------- 헬퍼

    private SeatHold hold(Concert concert, Seat seat, Member member) {
        return SeatHold.builder()
                .concert(concert)
                .seat(seat)
                .member(member)
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .build();
    }

    private Reservation reservation(Concert concert, Seat seat, Member member) {
        return Reservation.builder()
                .concert(concert)
                .seat(seat)
                .member(member)
                .build();
    }

    private Concert saveConcert(Venue venue, String title) {
        return concertRepository.save(Concert.builder()
                .title(title)
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

        Section section = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(150000)
                .rowCount(2)
                .seatPerRow(2)
                .venue(venue)
                .build());

        seatRepository.saveAll(section.createSeats(positions));
        return section;
    }
}
