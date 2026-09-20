package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
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
import com.ssafy.timo.global.config.notification.NotificationProperties;
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
 * 예매한 공연 일정 알림이 정해진 날짜와 시각에, 티켓 보유자에게만, 한 번씩 나가는지 실제 MySQL 로 확인한다.
 *
 * <p>알림은 공연 시작 시각이 아니라 <b>공연 날짜</b>의 09:00 에 나간다. 공연이 새벽이든 밤이든 같은 아침에
 * 나가는지, 그리고 아침 9시 전에 시작하는 공연에는 당일 알림이 나가지 않는지를 따로 본다.
 */
@IntegrationTest
class ShowReminderSweepTest {

    /** 9월 27일 공연의 7일 전 알림이 나가는 시각. 모든 테스트의 기본 기준 시각이다. */
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 9, 0);
    private static final int SEAT_PRICE = 150_000;

    @Autowired
    private ShowReminderSweep sweep;

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
    @DisplayName("7일 전: 공연 날짜의 7일 전 09:00 에 보유자에게 규약대로 저장된다")
    void sevenDaysBefore_notifiesHolderWithContractFields() {
        Concert concert = concert("로이킴 콘서트", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(1);
        Map<String, Object> row = jdbc.queryForMap(
                "select body, type, link_type, link_id, dedup_key from notification where member_id = ?",
                holder.getId());
        assertThat(row.get("body")).isEqualTo("로이킴 콘서트까지 일주일 남았어요");
        assertThat(row.get("type")).isEqualTo("SHOW_REMINDER");
        assertThat(row.get("link_type")).isEqualTo("CONCERT");
        assertThat(((Number) row.get("link_id")).longValue()).isEqualTo(concert.getId());
        assertThat(row.get("dedup_key")).isEqualTo("SHOW_REMINDER_D7:concert=" + concert.getId());
    }

    @Test
    @DisplayName("1일 전: 공연 날짜의 하루 전 09:00 에 나간다")
    void oneDayBefore_notifiesAt0900() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 21, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        assertThat(sweep.run(NOW, 500)).isEqualTo(1);

        assertThat(bodyOf(holder)).isEqualTo("내일은 공연 보는 날이에요");
        assertThat(keyOf(holder)).isEqualTo("SHOW_REMINDER_D1:concert=" + concert.getId());
    }

    @Test
    @DisplayName("당일: 공연 날짜 09:00 에 나간다")
    void sameDay_notifiesAt0900() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 20, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        assertThat(sweep.run(NOW, 500)).isEqualTo(1);

        assertThat(bodyOf(holder)).isEqualTo("오늘 공연 즐길 준비 되셨나요?");
        assertThat(keyOf(holder)).isEqualTo("SHOW_REMINDER_D0:concert=" + concert.getId());
    }

    @ParameterizedTest(name = "7일 전 알림 시각에서 {0}초 지난 시점이면 대상 {1}")
    @CsvSource({
            "-1, false",    // 알림 시각 1초 전. 아직 이르다
            "0, true",      // 정확히 알림 시각이다
            "3600, true",   // 보정 구간의 끝이다
            "3601, false"   // 보정 구간을 1초 넘겨 놓쳤다
    })
    @DisplayName("7일 전 알림의 시간 창 경계를 초 단위로 지킨다")
    void sevenDaysBefore_windowBoundaries(long secondsAfterSend, boolean expectedNotified) {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        hold(concert);

        int recorded = sweep.run(NOW.plusSeconds(secondsAfterSend), 500);

        assertThat(recorded).isEqualTo(expectedNotified ? 1 : 0);
    }

    @ParameterizedTest(name = "당일 알림 시각에서 {0}초 지난 시점이면 대상 {1}")
    @CsvSource({
            "-1, false",
            "0, true",
            "3600, true",
            "3601, false"
    })
    @DisplayName("당일 알림의 시간 창 경계를 초 단위로 지킨다")
    void sameDay_windowBoundaries(long secondsAfterSend, boolean expectedNotified) {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 20, 20, 0), ConcertStatus.ON_SALE);
        hold(concert);

        int recorded = sweep.run(NOW.plusSeconds(secondsAfterSend), 500);

        assertThat(recorded).isEqualTo(expectedNotified ? 1 : 0);
    }

    @ParameterizedTest(name = "공연이 {0} 이어도 7일 전 알림은 같은 날 09:00 에 나간다")
    @CsvSource({"2026-09-27T00:30:00", "2026-09-27T12:00:00", "2026-09-27T23:59:00"})
    @DisplayName("7일 전은 공연 시작 시각이 아니라 공연 날짜를 기준으로 09:00 에 나간다")
    void sevenDaysBefore_usesShowDateNotShowTime(LocalDateTime start) {
        Concert concert = concert("공연", start, ConcertStatus.ON_SALE);
        hold(concert);

        assertThat(sweep.run(NOW.minusSeconds(1), 500)).as("09:00 전").isZero();
        assertThat(sweep.run(NOW, 500)).as("09:00 정각").isEqualTo(1);
    }

    @Test
    @DisplayName("아침 9시 전에 시작하는 공연에는 당일 알림이 나가지 않는다")
    void showStartingBeforeNine_hasNoSameDayNotification() {
        Concert earlyShow = concert("이른 공연", LocalDateTime.of(2026, 9, 20, 8, 0), ConcertStatus.ON_SALE);
        hold(earlyShow);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("시작 시각이 정확히 지금인 공연에는 알림이 나가지 않는다")
    void showStartingExactlyNow_isNotNotified() {
        Concert startingNow = concert("지금 시작하는 공연", NOW, ConcertStatus.ON_SALE);
        hold(startingNow);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("당일 알림 시각 직후에 시작하는 공연에는 나간다")
    void showStartingJustAfterNine_getsSameDayNotification() {
        Concert show = concert("아침 공연", LocalDateTime.of(2026, 9, 20, 9, 30), ConcertStatus.ON_SALE);
        hold(show);

        assertThat(sweep.run(NOW, 500)).isEqualTo(1);
    }

    @Test
    @DisplayName("취소된 공연은 알림이 없고, 매진된 공연은 있다")
    void canceledIsExcludedButSoldOutIsNot() {
        Concert canceled = concert("취소된 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.CANCELED);
        Concert soldOut = concert("매진 공연", LocalDateTime.of(2026, 9, 27, 21, 0), ConcertStatus.SOLD_OUT);
        hold(canceled);
        hold(soldOut);

        sweep.run(NOW, 500);

        assertThat(notifiedMembers("SHOW_REMINDER_D7", canceled)).isEmpty();
        assertThat(notifiedMembers("SHOW_REMINDER_D7", soldOut)).hasSize(1);
    }

    @Test
    @DisplayName("보유자에게만 가고, 취소된 예매나 다른 공연의 보유자는 받지 않는다")
    void onlyHoldersOfThatConcert_areNotified() {
        Concert target = concert("대상 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        Concert other = concert("다른 공연", LocalDateTime.of(2026, 12, 25, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(target);
        Ticket cancelled = holdTicket(member(), target);
        cancelled.getReservation().cancel(NOW, NOW.plusMinutes(10));
        em.flush();
        Member otherHolder = hold(other);
        member(); // 티켓이 없는 회원

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(1);
        assertThat(notifiedMembers("SHOW_REMINDER_D7", target)).containsExactly(holder.getId());
        assertThat(count(otherHolder)).isZero();
    }

    @Test
    @DisplayName("양도된 티켓은 판 사람이 아니라 산 사람에게 보낸다")
    void tradedTicket_notifiesBuyerOnly() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        Member seller = member();
        Member buyer = member();
        Ticket ticket = holdTicket(seller, concert);
        trade(ticket, seller, buyer);

        sweep.run(NOW, 500);

        assertThat(notifiedMembers("SHOW_REMINDER_D7", concert)).containsExactly(buyer.getId());
    }

    @Test
    @DisplayName("같은 주기를 다시 돌거나 창 안에서 시간이 흘러도 알림은 늘지 않는다")
    void repeatedRuns_doNotDuplicate() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        int first = sweep.run(NOW, 500);
        int again = sweep.run(NOW, 500);
        int later = sweep.run(NOW.plusMinutes(30), 500);

        assertThat(first).isEqualTo(1);
        assertThat(again).isZero();
        assertThat(later).isZero();
        assertThat(count(holder)).isEqualTo(1);
    }

    @Test
    @DisplayName("같은 공연의 7일 전, 1일 전, 당일은 각자의 키로 따로 나간다")
    void eachPhase_isAnIndependentNotification() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        sweep.run(LocalDateTime.of(2026, 9, 20, 9, 0), 500);
        sweep.run(LocalDateTime.of(2026, 9, 26, 9, 0), 500);
        sweep.run(LocalDateTime.of(2026, 9, 27, 9, 0), 500);

        assertThat(jdbc.queryForList("select dedup_key from notification where member_id = ? order by notification_id",
                String.class, holder.getId()))
                .containsExactly(
                        "SHOW_REMINDER_D7:concert=" + concert.getId(),
                        "SHOW_REMINDER_D1:concert=" + concert.getId(),
                        "SHOW_REMINDER_D0:concert=" + concert.getId());
    }

    @Test
    @DisplayName("서버가 오래 내려가 있었어도 보정 구간이 길면 놓친 시점을 모두 보낸다")
    void longOutage_sendsEveryMissedPhaseWithinCatchUp() {
        ShowReminderSweep weekLong = withCatchUp(Duration.ofDays(7));
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 21, 20, 0), ConcertStatus.ON_SALE);
        Member holder = hold(concert);

        // 7일 전(9/14 09:00)과 1일 전(9/20 09:00) 알림 시각이 모두 지났고 당일(9/21 09:00)은 아직이다.
        int recorded = weekLong.run(LocalDateTime.of(2026, 9, 20, 10, 0), 500);

        assertThat(recorded).isEqualTo(2);
        assertThat(jdbc.queryForList("select dedup_key from notification where member_id = ?", String.class,
                holder.getId()))
                .containsExactlyInAnyOrder(
                        "SHOW_REMINDER_D7:concert=" + concert.getId(),
                        "SHOW_REMINDER_D1:concert=" + concert.getId());
    }

    @Test
    @DisplayName("보정 구간이 길어도 이미 시작한 공연에는 어떤 알림도 보내지 않는다")
    void alreadyStarted_isNeverNotified() {
        ShowReminderSweep longCatchUp = withCatchUp(Duration.ofDays(3));
        Concert concert = concert("이미 시작한 공연", NOW.minusHours(1), ConcertStatus.ON_SALE);
        hold(concert);

        assertThat(longCatchUp.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("공연이 한참 뒤이면 알림 시각이 오지 않았으니 보내지 않는다")
    void farFutureShow_isNotNotified() {
        Concert concert = concert("먼 공연", NOW.plusDays(30), ConcertStatus.ON_SALE);
        hold(concert);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("보유자가 없는 공연이면 0건이다")
    void noHolders_returnsZero() {
        concert("보유자 없는 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("처리 상한에 닿으면 멈추고, 남은 사람은 다음 주기에 이어서 받으며 중복은 없다")
    void limit_stopsAndContinuesNextRun() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        List<Member> holders = holdMany(concert, 5);

        int first = sweep.run(NOW, 2);
        int second = sweep.run(NOW.plusMinutes(1), 2);
        int third = sweep.run(NOW.plusMinutes(2), 2);
        int fourth = sweep.run(NOW.plusMinutes(3), 2);

        assertThat(List.of(first, second, third, fourth)).containsExactly(2, 2, 1, 0);
        assertThat(notifiedMembers("SHOW_REMINDER_D7", concert))
                .containsExactlyInAnyOrderElementsOf(holders.stream().map(Member::getId).toList());
    }

    @Test
    @DisplayName("상한은 공연과 시점을 넘나들며 하나로 센다")
    void limit_isSharedAcrossConcertsAndPhases() {
        Concert sevenDay = concert("7일 전 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.ON_SALE);
        Concert sameDay = concert("당일 공연", LocalDateTime.of(2026, 9, 20, 20, 0), ConcertStatus.ON_SALE);
        holdMany(sevenDay, 2);
        holdMany(sameDay, 2);

        assertThat(sweep.run(NOW, 3)).isEqualTo(3);
        assertThat(sweep.run(NOW.plusMinutes(1), 3)).isEqualTo(1);
    }

    // ---------------------------------------------------------------- 헬퍼

    private ShowReminderSweep withCatchUp(Duration catchUp) {
        return new ShowReminderSweep(concertRepository, ticketOwnerReader, recorder,
                new NotificationProperties(500, catchUp));
    }

    private long count(Member member) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, member.getId());
    }

    private String bodyOf(Member member) {
        return jdbc.queryForObject("select body from notification where member_id = ?", String.class, member.getId());
    }

    private String keyOf(Member member) {
        return jdbc.queryForObject(
                "select dedup_key from notification where member_id = ?", String.class, member.getId());
    }

    private List<Long> notifiedMembers(String keyPrefix, Concert concert) {
        return jdbc.queryForList("select member_id from notification where dedup_key = ?", Long.class,
                keyPrefix + ":concert=" + concert.getId());
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
                .openAt(start.minusDays(60))
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
