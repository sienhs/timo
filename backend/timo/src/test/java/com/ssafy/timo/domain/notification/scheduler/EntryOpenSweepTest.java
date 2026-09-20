package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.config.NotificationProperties;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.math.BigInteger;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 입장 가능 알림이 정해진 시각에, 정해진 사람에게, 한 번만 나가는지 실제 MySQL 로 확인한다.
 *
 * <p>기준 시각을 직접 넘기므로 타이머를 기다리지 않는다. 시간 창의 경계는 초 단위로 본다. 경계에서 하루
 * 종일 어긋나도 눈에 띄지 않는 종류의 버그라, 정확히 걸치는 값과 1초 벗어난 값을 함께 확인한다.
 */
@IntegrationTest
class EntryOpenSweepTest {

    /** 이 시각 기준으로 알림 창은 시작이 11:00 ~ 12:00 인 공연이다. */
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 10, 0);
    private static final int SEAT_PRICE = 150_000;

    @Autowired
    private EntryOpenSweep sweep;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private TicketOwnerReader ticketOwnerReader;

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

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

    @Autowired
    private JdbcTemplate jdbc;

    private Venue venue;
    private Section section;
    private List<Seat> seats;
    private int nextSeat;

    @BeforeEach
    void setUpFixtures() {
        venue = venueRepository.save(Venue.builder()
                .name("고척돔-" + UUID.randomUUID().toString().substring(0, 6))
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());
        List<SeatPosition> positions = IntStream.rangeClosed(1, 4).boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 5).mapToObj(col -> new SeatPosition(row, col)))
                .toList();
        section = sectionRepository.save(Section.builder()
                .name("1층 A블록").price(SEAT_PRICE).rowCount(4).seatPerRow(5).venue(venue).build());
        seatRepository.saveAll(section.createSeats(positions));
        seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
    }

    @Test
    @DisplayName("창 안의 공연은 보유자에게 알림이 저장되고 본문, 이동 화면, 중복 방지 키가 규약대로다")
    void concertInWindow_notifiesHolderWithContractFields() {
        Concert concert = concert("로이킴 콘서트", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(1);
        Map<String, Object> row = jdbc.queryForMap(
                "select body, type, link_type, link_id, dedup_key from notification where member_id = ?",
                holder.getId());
        assertThat(row.get("body")).isEqualTo("로이킴 콘서트, 지금부터 입장할 수 있어요");
        assertThat(row.get("type")).isEqualTo("ENTRY_OPEN");
        assertThat(row.get("link_type")).isEqualTo("CONCERT");
        assertThat(((Number) row.get("link_id")).longValue()).isEqualTo(concert.getId());
        assertThat(row.get("dedup_key")).isEqualTo("ENTRY_OPEN:concert=" + concert.getId());
    }

    @ParameterizedTest(name = "시작이 지금 + {0}초이면 알림 대상 {1}")
    @CsvSource({
            "7200, true",   // 알림 시각이 정확히 지금이다
            "7201, false",  // 알림 시각이 1초 뒤다. 아직 이르다
            "3600, true",   // 알림 시각이 정확히 보정 구간의 끝이다
            "3599, false",  // 보정 구간을 1초 넘겨 놓쳤다
            "5400, true"
    })
    @DisplayName("시간 창의 경계를 초 단위로 지킨다")
    void windowBoundaries(long secondsFromNow, boolean expectedNotified) {
        Concert concert = concert("경계 공연", NOW.plusSeconds(secondsFromNow), ConcertStatus.ON_SALE);
        hold(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(expectedNotified ? 1 : 0);
    }

    @Test
    @DisplayName("취소된 공연은 알림이 없고, 매진된 공연은 있다")
    void canceledIsExcludedButSoldOutIsNot() {
        Concert canceled = concert("취소된 공연", NOW.plusMinutes(90), ConcertStatus.CANCELED);
        Concert soldOut = concert("매진 공연", NOW.plusMinutes(100), ConcertStatus.SOLD_OUT);
        hold(canceled);
        hold(soldOut);

        sweep.run(NOW, 500);

        assertThat(notificationsFor(canceled)).isZero();
        assertThat(notificationsFor(soldOut)).isEqualTo(1);
    }

    @Test
    @DisplayName("취소된 예매의 회원에게는 보내지 않는다")
    void cancelledReservation_isNotNotified() {
        Concert concert = concert("공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        Member holder = hold(concert);
        Ticket cancelled = holdTicket(member(), concert);
        cancelled.getReservation().cancel(NOW, NOW.plusMinutes(10));
        em.flush();

        sweep.run(NOW, 500);

        assertThat(notifiedMembers(concert)).containsExactly(holder.getId());
    }

    @Test
    @DisplayName("양도된 티켓은 판 사람이 아니라 산 사람에게 보낸다")
    void tradedTicket_notifiesBuyerOnly() {
        Concert concert = concert("공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        Member seller = member();
        Member buyer = member();
        Ticket ticket = holdTicket(seller, concert);
        trade(ticket, seller, buyer);

        sweep.run(NOW, 500);

        assertThat(notifiedMembers(concert)).containsExactly(buyer.getId());
    }

    @Test
    @DisplayName("같은 주기를 다시 돌아도, 창 안에서 시간이 흘러도 알림은 늘지 않는다")
    void repeatedRuns_doNotDuplicate() {
        Concert concert = concert("공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        hold(concert);

        int first = sweep.run(NOW, 500);
        int again = sweep.run(NOW, 500);
        int later = sweep.run(NOW.plusMinutes(30), 500);

        assertThat(first).isEqualTo(1);
        assertThat(again).isZero();
        assertThat(later).isZero();
        assertThat(notificationsFor(concert)).isEqualTo(1);
    }

    @Test
    @DisplayName("놓쳤던 알림도 보정 구간 안이면 다음 주기에 나간다")
    void missedNotification_isSentWithinCatchUp() {
        // 알림 시각은 09:20 이었다. 지금 10:00 이니 40분 놓쳤지만 보정 구간(1시간) 안이다.
        Concert concert = concert("공연", NOW.plusMinutes(80), ConcertStatus.ON_SALE);
        hold(concert);

        assertThat(sweep.run(NOW, 500)).isEqualTo(1);
    }

    @Test
    @DisplayName("공연이 여럿이면 공연마다 각자의 키로 따로 나간다")
    void multipleConcerts_areNotifiedSeparately() {
        Concert first = concert("첫 공연", NOW.plusMinutes(70), ConcertStatus.ON_SALE);
        Concert second = concert("둘째 공연", NOW.plusMinutes(100), ConcertStatus.ON_SALE);
        Member both = member();
        holdTicket(both, first);
        holdTicket(both, second);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(2);
        assertThat(notificationsFor(first)).isEqualTo(1);
        assertThat(notificationsFor(second)).isEqualTo(1);
    }

    @Test
    @DisplayName("처리 상한에 닿으면 멈추고, 남은 사람은 다음 주기에 이어서 받으며 중복은 없다")
    void limit_stopsAndContinuesNextRun() {
        Concert concert = concert("공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        List<Member> holders = holdMany(concert, 5);

        int first = sweep.run(NOW, 2);
        int second = sweep.run(NOW.plusMinutes(1), 2);
        int third = sweep.run(NOW.plusMinutes(2), 2);
        int fourth = sweep.run(NOW.plusMinutes(3), 2);

        assertThat(List.of(first, second, third, fourth)).containsExactly(2, 2, 1, 0);
        assertThat(notifiedMembers(concert)).containsExactlyInAnyOrderElementsOf(ids(holders));
    }

    @Test
    @DisplayName("상한은 공연을 넘나들며 하나로 센다")
    void limit_isSharedAcrossConcerts() {
        Concert first = concert("첫 공연", NOW.plusMinutes(70), ConcertStatus.ON_SALE);
        Concert second = concert("둘째 공연", NOW.plusMinutes(100), ConcertStatus.ON_SALE);
        holdMany(first, 2);
        holdMany(second, 2);

        assertThat(sweep.run(NOW, 3)).isEqualTo(3);
        assertThat(sweep.run(NOW.plusMinutes(1), 3)).isEqualTo(1);
    }

    @Test
    @DisplayName("이미 받은 사람이 앞에 몰려 있어도 상한 안에서 뒤의 새 사람까지 이어 간다")
    void limit_skipsAlreadyNotifiedAndReachesNewOnes() {
        Concert concert = concert("공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        List<Member> holders = holdMany(concert, 4);
        String key = NotificationType.ENTRY_OPEN.concertKey(concert.getId());
        recorder.recordAll(ids(holders.subList(0, 2)), NotificationType.ENTRY_OPEN, "이미 보냄", concert.getId(), key);

        int recorded = sweep.run(NOW, 2);

        assertThat(recorded).isEqualTo(2);
        assertThat(notifiedMembers(concert)).containsExactlyInAnyOrderElementsOf(ids(holders));
    }

    @Test
    @DisplayName("보정 구간이 알림 시각 간격보다 길어도 이미 시작한 공연에는 보내지 않는다")
    void longCatchUp_doesNotNotifyStartedConcerts() {
        EntryOpenSweep longCatchUp = new EntryOpenSweep(concertRepository, ticketOwnerReader, recorder,
                new NotificationProperties(500, Duration.ofHours(5)));
        Concert started = concert("이미 시작한 공연", NOW.minusMinutes(10), ConcertStatus.ON_SALE);
        Concert upcoming = concert("곧 시작할 공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);
        hold(started);
        hold(upcoming);

        longCatchUp.run(NOW, 500);

        assertThat(notificationsFor(started)).isZero();
        assertThat(notificationsFor(upcoming)).isEqualTo(1);
    }

    @Test
    @DisplayName("보유자가 없는 공연이나 창 안에 공연이 없으면 0건이다")
    void nothingToNotify_returnsZero() {
        concert("보유자 없는 공연", NOW.plusMinutes(90), ConcertStatus.ON_SALE);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    // ---------------------------------------------------------------- 헬퍼

    private long notificationsFor(Concert concert) {
        return jdbc.queryForObject("select count(*) from notification where dedup_key = ?", Long.class,
                NotificationType.ENTRY_OPEN.concertKey(concert.getId()));
    }

    private List<Long> notifiedMembers(Concert concert) {
        return jdbc.queryForList("select member_id from notification where dedup_key = ?", Long.class,
                NotificationType.ENTRY_OPEN.concertKey(concert.getId()));
    }

    private static List<Long> ids(List<Member> members) {
        return members.stream().map(Member::getId).toList();
    }

    private Member hold(Concert concert) {
        Member member = member();
        holdTicket(member, concert);
        return member;
    }

    private List<Member> holdMany(Concert concert, int count) {
        List<Member> members = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            members.add(hold(concert));
        }
        return members;
    }

    /** 예매하고 발행까지 끝난 티켓. 좌석은 테스트 안에서 겹치지 않게 하나씩 쓴다. */
    private Ticket holdTicket(Member member, Concert concert) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert).member(member).seat(seats.get(nextSeat++)).build());
        Ticket ticket = ticketRepository.save(Ticket.builder().reservation(reservation).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
    }

    private void trade(Ticket ticket, Member seller, Member buyer) {
        TicketListing listing = ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(), seller.getId(), ticket.getReservation().getConcert(), section,
                ticket.getReservation().getSeat().getSeatNo(), ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L, SEAT_PRICE, NOW.minusDays(1)));
        em.flush();
        ticketListingRepository.markSoldIfListed(listing.getId(), NOW.minusHours(1));
        TicketListing sold = ticketListingRepository.findById(listing.getId()).orElseThrow();
        ticketTradeRepository.save(TicketTrade.record(sold, buyer.getId(), NOW.minusHours(1)));
        em.flush();
    }

    /** 상태는 리플렉션으로 넣는다. 공연은 생성 시 SCHEDULED 로 고정되고 상태를 옮기는 메서드가 없다. */
    private Concert concert(String title, LocalDateTime start, ConcertStatus status) {
        Concert concert = concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(start)
                .endDate(start.plusHours(3))
                .openAt(start.minusDays(30))
                .venue(venue)
                .build());
        ReflectionTestUtils.setField(concert, "status", status);
        em.flush();
        return concert;
    }

    private Member member() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());
    }
}
