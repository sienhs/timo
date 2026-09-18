package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
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
import org.springframework.test.util.ReflectionTestUtils;

import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 공연 상태 스윕 통합 테스트.
 *
 * <p>타이머를 기다리지 않고 빈을 직접 부른다. test 프로파일은 {@code scheduling.enabled: false} 라
 * 타이머가 아예 뜨지 않는데 그건 의도한 것이다({@code SchedulingConfig} 주석 참고). 검증할 것은
 * "주기적으로 불린다" 가 아니라 "불렸을 때 무엇을 바꾸고 무엇을 그냥 두는가" 다.
 *
 * <p>벌크 UPDATE 는 영속성 컨텍스트를 우회하므로 검증은 반드시 다시 조회해서 한다. 들고 있던
 * 엔티티를 그대로 보면 갱신 전 값이 남아 있어 통과해야 할 테스트가 실패하거나 그 반대가 된다.
 */
@IntegrationTest
class ConcertStatusSchedulerTest {

    @Autowired
    private ConcertStatusScheduler scheduler;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private SeatHoldRepository seatHoldRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private EntityManager em;

    private Venue venue;
    private Member organizer;
    private int memberSeq;

    @BeforeEach
    void setUpFixtures() {
        venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());
        organizer = memberRepository.save(Member.builder()
                .phoneNumber("01055556666")
                .name("주최자")
                .nickname("주최자")
                .build());
        em.flush();
    }

    @Test
    @DisplayName("오픈 시각이 지난 공연을 예매 중으로 올린다")
    void opensConcertWhoseSaleTimeHasArrived() {
        Long id = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(-1), daysFromNow(10), daysFromNow(10), true);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("온체인 등록이 끝나지 않은 공연은 오픈 시각이 지났어도 올리지 않는다")
    void leavesConcertThatIsNotRegisteredOnChain() {
        // showId 가 없으면 결제가 IllegalStateException 으로 터진다. 목록에 예매 중으로 내보내면 안 된다.
        Long id = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(-1), daysFromNow(10), daysFromNow(10), false);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.SCHEDULED);
    }

    @Test
    @DisplayName("아직 오픈 시각 전인 공연은 그대로 둔다")
    void leavesConcertBeforeItsOpenAt() {
        Long id = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(3), daysFromNow(10), daysFromNow(10), true);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.SCHEDULED);
    }

    @Test
    @DisplayName("끝난 공연을 종료로 내린다")
    void closesConcertThatHasEnded() {
        Long id = saveConcert(ConcertStatus.ON_SALE, daysFromNow(-30), daysFromNow(-2), daysFromNow(-2), true);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.CLOSED);
    }

    @Test
    @DisplayName("예매를 열어 본 적 없는 공연도 날짜가 지나면 종료로 내린다")
    void closesConcertThatNeverWentOnSale() {
        Long id = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(-30), daysFromNow(-2), daysFromNow(-2), false);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.CLOSED);
    }

    @Test
    @DisplayName("취소된 공연은 날짜가 지나도 종료로 덮지 않는다")
    void keepsCanceledConcertAsCanceled() {
        Long id = saveConcert(ConcertStatus.CANCELED, daysFromNow(-30), daysFromNow(-2), daysFromNow(-2), true);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.CANCELED);
    }

    @Test
    @DisplayName("종료일이 없는 공연은 끝났다고 단정하지 않는다")
    void keepsConcertWithoutEndDate() {
        Long id = saveConcert(ConcertStatus.ON_SALE, daysFromNow(-30), daysFromNow(-2), null, true);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("오픈 시각과 종료일이 모두 지난 공연은 열리지 않고 곧바로 종료가 된다")
    void closesRatherThanOpensWhenBothConditionsApply() {
        // 닫는 쿼리를 먼저 돌리는 이유. 여는 쪽이 먼저면 SCHEDULED -> ON_SALE -> CLOSED 로 두 번 쓴다.
        Long id = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(-30), daysFromNow(-2), daysFromNow(-2), true);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.CLOSED);
    }

    @Test
    @DisplayName("한 번 돈 뒤에 다시 돌아도 더 바꿀 것이 없다")
    void isIdempotentAcrossRuns() {
        Long opening = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(-1), daysFromNow(10), daysFromNow(10), true);
        Long closing = saveConcert(ConcertStatus.ON_SALE, daysFromNow(-30), daysFromNow(-2), daysFromNow(-2), true);

        scheduler.sweep();
        scheduler.sweep();

        assertThat(statusOf(opening)).isEqualTo(ConcertStatus.ON_SALE);
        assertThat(statusOf(closing)).isEqualTo(ConcertStatus.CLOSED);
    }

    @Test
    @DisplayName("좌석이 전부 팔리면 매진으로 넘긴다")
    void marksSoldOutWhenEverySeatIsSold() {
        Long id = onSaleConcert();
        List<Seat> seats = saveSeats(3);
        seats.forEach(seat -> pay(id, seat));

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.SOLD_OUT);
    }

    @Test
    @DisplayName("한 자리라도 남아 있으면 예매 중으로 둔다")
    void keepsOnSaleWhileAnySeatRemains() {
        Long id = onSaleConcert();
        List<Seat> seats = saveSeats(3);
        pay(id, seats.get(0));
        pay(id, seats.get(1));

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("선점만 걸린 자리는 남은 자리로 본다")
    void treatsHeldSeatAsRemaining() {
        // 선점을 팔린 것으로 세면, 5분 뒤 만료로 자리가 돌아올 때 매진을 되돌려야 한다.
        Long id = onSaleConcert();
        List<Seat> seats = saveSeats(3);
        pay(id, seats.get(0));
        pay(id, seats.get(1));
        hold(id, seats.get(2));

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("취소된 자리는 남은 자리로 본다 - 취소표로 다시 팔린다")
    void treatsCanceledSeatAsRemaining() {
        Long id = onSaleConcert();
        List<Seat> seats = saveSeats(3);
        pay(id, seats.get(0));
        pay(id, seats.get(1));
        payAndCancel(id, seats.get(2));

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("매진 뒤에 취소가 나면 예매 중으로 되돌린다")
    void reopensSoldOutConcertWhenSeatIsCanceled() {
        Long id = onSaleConcert();
        List<Seat> seats = saveSeats(2);
        Reservation first = pay(id, seats.get(0));
        pay(id, seats.get(1));

        scheduler.sweep();
        assertThat(statusOf(id)).isEqualTo(ConcertStatus.SOLD_OUT);

        // 스윕의 벌크 UPDATE 가 영속성 컨텍스트를 비워 first 는 준영속이다. 그대로 cancel() 하면
        // DB 에 닿지 않아 아무 일도 일어나지 않는다.
        reservationRepository.findById(first.getId()).orElseThrow().cancel(LocalDateTime.now(), LocalDateTime.now());
        em.flush();

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("온체인 등록이 안 된 매진 공연은 되돌리지 않는다")
    void doesNotReopenConcertThatIsNotRegisteredOnChain() {
        // 시드나 부트스트랩 SQL 이 상태를 직접 심을 수 있어, 그 경로로 들어온 행은 올리지 않는다.
        Long id = saveConcert(ConcertStatus.SOLD_OUT, daysFromNow(-1), daysFromNow(10), daysFromNow(10), false);
        saveSeats(2);

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.SOLD_OUT);
    }

    @Test
    @DisplayName("좌석을 아직 등록하지 않은 공연장은 매진으로 보지 않는다")
    void doesNotMarkSoldOutWhenVenueHasNoSeats() {
        // 좌석 수가 0 이면 "전부 팔렸다" 가 공허하게 참이 된다. 자리가 없는 공연이 매진일 수는 없다.
        Long id = onSaleConcert();

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.ON_SALE);
    }

    @Test
    @DisplayName("예매 중이 아닌 공연은 좌석이 다 팔렸어도 매진으로 넘기지 않는다")
    void doesNotMarkSoldOutWhenNotOnSale() {
        Long id = saveConcert(ConcertStatus.SCHEDULED, daysFromNow(3), daysFromNow(10), daysFromNow(10), true);
        List<Seat> seats = saveSeats(2);
        seats.forEach(seat -> pay(id, seat));

        scheduler.sweep();

        assertThat(statusOf(id)).isEqualTo(ConcertStatus.SCHEDULED);
    }

    /** 예매 창 안에 있는 예매 중 공연. 시간 전이에는 걸리지 않으므로 매진 판정만 남는다. */
    private Long onSaleConcert() {
        return saveConcert(ConcertStatus.ON_SALE, daysFromNow(-1), daysFromNow(10), daysFromNow(10), true);
    }

    /** 이 공연장에 {@code count} 자리를 만든다. 한 행에 나란히 붙이면 충분하다. */
    private List<Seat> saveSeats(int count) {
        Section section = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(150_000)
                .rowCount(1)
                .seatPerRow(count)
                .venue(venue)
                .build());
        List<Seat> seats = seatRepository.saveAll(section.createSeats(
                IntStream.rangeClosed(1, count)
                        .mapToObj(col -> new SeatPosition(1, col))
                        .toList()));
        em.flush();
        return seats;
    }

    private Reservation pay(Long concertId, Seat seat) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concertRepository.findById(concertId).orElseThrow())
                .member(newBuyer())
                .seat(seat)
                .build());
        em.flush();
        return reservation;
    }

    private void payAndCancel(Long concertId, Seat seat) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concertRepository.findById(concertId).orElseThrow())
                .member(newBuyer())
                .seat(seat)
                .build());
        reservation.cancel(LocalDateTime.now(), LocalDateTime.now());
        em.flush();
    }

    private void hold(Long concertId, Seat seat) {
        seatHoldRepository.save(SeatHold.builder()
                .concert(concertRepository.findById(concertId).orElseThrow())
                .seat(seat)
                .member(newBuyer())
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .build());
        em.flush();
    }

    /** 구매자를 매번 새로 만든다. 한 회원은 공연마다 한 자리만 가질 수 있어 재사용할 수 없다. */
    private Member newBuyer() {
        memberSeq++;
        return memberRepository.save(Member.builder()
                .phoneNumber("0102222%04d".formatted(memberSeq))
                .name("구매자")
                .nickname("구매자" + memberSeq)
                .build());
    }

    private static LocalDateTime daysFromNow(long days) {
        return LocalDateTime.now().plusDays(days);
    }

    private ConcertStatus statusOf(Long concertId) {
        em.clear();
        return concertRepository.findById(concertId).orElseThrow().getStatus();
    }

    /**
     * 공연 하나를 원하는 상태와 날짜로 심는다.
     *
     * <p>상태는 리플렉션으로 넣는다. {@code Concert} 는 생성 시점에 {@code SCHEDULED} 로 고정되고
     * 상태를 옮기는 메서드가 없다 - 그 전이를 맡는 것이 바로 이 테스트가 검증하는 스윕이다.
     */
    private Long saveConcert(ConcertStatus status,
                             LocalDateTime openAt,
                             LocalDateTime startDate,
                             LocalDateTime endDate,
                             boolean registeredOnChain) {
        Concert concert = concertRepository.save(Concert.builder()
                .title("공연 " + status + " " + System.nanoTime())
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(openAt)
                .startDate(startDate)
                .endDate(endDate)
                .venue(venue)
                .build());
        ReflectionTestUtils.setField(concert, "status", status);
        if (registeredOnChain) {
            concert.prepareForSale(organizer);
            concert.confirmRegistered(BigInteger.ONE);
        }
        em.flush();
        em.clear();
        return concert.getId();
    }
}
