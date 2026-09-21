package com.ssafy.timo.domain.notification.scheduler;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.entity.ConcertAlarm;
import com.ssafy.timo.domain.alarm.repository.ConcertAlarmRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler.SweepResult;
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
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 진짜 스케줄러로 진짜 스윕 넷을 돌려, 스윕을 하나씩 볼 때는 안 보이는 것을 확인한다.
 *
 * <p>스윕별 테스트는 각 스윕이 정해진 시각에 정해진 사람에게 보내는지를 본다. 여기서는 그것들이 <b>함께</b>
 * 돌 때의 성질을 본다. 실제 배포에서는 1분마다 시각이 흘러가므로, 그 시간을 그대로 흉내 내 한 알림이 정확히 한 번,
 * 처음 도래한 주기에 나가는지 본다. 시각은 스윕에 직접 넘겨서 고정한다. 타이머를 기다리지 않는다.
 */
@IntegrationTest
class NotificationSweepScenarioTest {

    private static final int SEAT_PRICE = 150_000;

    @Autowired
    private NotificationSweepScheduler scheduler;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private ConcertAlarmRepository alarmRepository;

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
        List<SeatPosition> positions = IntStream.rangeClosed(1, 6).boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 5).mapToObj(col -> new SeatPosition(row, col)))
                .toList();
        section = sectionRepository.save(Section.builder()
                .name("1층 A블록").price(SEAT_PRICE).rowCount(6).seatPerRow(5).venue(venue).build());
        seatRepository.saveAll(section.createSeats(positions));
        seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
    }

    // ---------------------------------------------------------------- 소유자 판정: 재양도

    @Test
    @DisplayName("재양도(A→B→C)되면 입장 알림과 당일 일정 알림 모두 마지막 구매자 C에게만 간다")
    void resale_notifiesOnlyTheLastBuyer() {
        LocalDateTime now = LocalDateTime.of(2026, 9, 20, 9, 0);
        Concert concert = concert("공연", now.plusHours(2)); // 입장 알림도 당일 알림도 09:00
        Member a = member();
        Member b = member();
        Member c = member();
        Ticket ticket = holdTicket(a, concert);
        trade(ticket, a, b, now.minusDays(2));
        trade(ticket, b, c, now.minusDays(1));

        scheduler.runOnce(now);

        assertThat(notifiedMembers("ENTRY_OPEN:concert=" + concert.getId())).containsExactly(c.getId());
        assertThat(notifiedMembers("SHOW_REMINDER_D0:concert=" + concert.getId())).containsExactly(c.getId());
        assertThat(count(a)).isZero();
        assertThat(count(b)).isZero();
    }

    @Test
    @DisplayName("양도 후에는 산 사람에게만 가고 판 사람에게는 가지 않는다")
    void transfer_notifiesBuyerNotSeller() {
        LocalDateTime now = LocalDateTime.of(2026, 9, 20, 9, 0);
        Concert concert = concert("공연", now.plusHours(2));
        Member seller = member();
        Member buyer = member();
        trade(holdTicket(seller, concert), seller, buyer, now.minusDays(1));

        scheduler.runOnce(now);

        assertThat(count(buyer)).isEqualTo(2);
        assertThat(count(seller)).isZero();
    }

    // ---------------------------------------------------------------- 같은 주기에 겹치는 알림

    @Test
    @DisplayName("같은 주기에 입장 알림과 당일 일정 알림이 겹치면 둘 다 각자의 키로 나간다")
    void sameTick_entryAndSameDayReminder_bothSent() {
        LocalDateTime now = LocalDateTime.of(2026, 9, 20, 9, 0);
        Concert concert = concert("로이킴 콘서트", now.plusHours(2));
        Member holder = member();
        holdTicket(holder, concert);

        List<SweepResult> results = scheduler.runOnce(now);

        assertThat(recordedBy(results, "ENTRY_OPEN")).isEqualTo(1);
        assertThat(recordedBy(results, "SHOW_REMINDER")).isEqualTo(1);
        assertThat(jdbc.queryForList("select dedup_key from notification where member_id = ? order by dedup_key",
                String.class, holder.getId()))
                .containsExactly("ENTRY_OPEN:concert=" + concert.getId(),
                        "SHOW_REMINDER_D0:concert=" + concert.getId());
        assertThat(jdbc.queryForList("select body from notification where member_id = ? order by dedup_key",
                String.class, holder.getId()))
                .containsExactly("로이킴 콘서트, 지금부터 입장할 수 있어요", "오늘 로이킴 콘서트 즐길 준비 되셨나요?");
    }

    @Test
    @DisplayName("네 스윕이 모두 돌고, 아무 데이터가 없어도 실패하지 않는다")
    void allFourSweepsRun_andNoneFailsOnEmptyData() {
        List<SweepResult> results = scheduler.runOnce(LocalDateTime.of(2026, 9, 20, 9, 0));

        assertThat(results).extracting(SweepResult::name)
                .containsExactlyInAnyOrder("ENTRY_OPEN", "CONCERT_OPEN", "SHOW_REMINDER", "MARKET_NEW_LISTING");
        assertThat(results).extracting(SweepResult::failed).containsOnly(false);
    }

    // ---------------------------------------------------------------- 시간 흐름: 정확히 한 번, 처음 도래한 주기에

    @Test
    @DisplayName("1분 간격으로 시간이 흐르면 입장 알림은 알림 시각의 주기에 모두에게 한 번씩만 나간다")
    void timeline_entryOpen_firesOnceAtSendTime() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 20, 20, 0));
        holdMany(concert, 2);

        List<Fire> fires = tick(LocalDateTime.of(2026, 9, 20, 17, 50), LocalDateTime.of(2026, 9, 20, 20, 0));

        assertThat(firesOf(fires, "ENTRY_OPEN"))
                .containsExactly(new Fire("ENTRY_OPEN", LocalDateTime.of(2026, 9, 20, 18, 0), 2));
    }

    @Test
    @DisplayName("공연 일정 알림은 7일 전, 하루 전, 당일 09:00 주기에 각각 한 번씩만 나간다")
    void timeline_showReminder_firesOncePerPhase() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0));
        holdMany(concert, 2);
        List<Fire> fires = new ArrayList<>();

        fires.addAll(tick(LocalDateTime.of(2026, 9, 20, 8, 55), LocalDateTime.of(2026, 9, 20, 10, 10)));
        fires.addAll(tick(LocalDateTime.of(2026, 9, 26, 8, 55), LocalDateTime.of(2026, 9, 26, 10, 10)));
        fires.addAll(tick(LocalDateTime.of(2026, 9, 27, 8, 55), LocalDateTime.of(2026, 9, 27, 10, 10)));

        assertThat(firesOf(fires, "SHOW_REMINDER")).containsExactly(
                new Fire("SHOW_REMINDER", LocalDateTime.of(2026, 9, 20, 9, 0), 2),
                new Fire("SHOW_REMINDER", LocalDateTime.of(2026, 9, 26, 9, 0), 2),
                new Fire("SHOW_REMINDER", LocalDateTime.of(2026, 9, 27, 9, 0), 2));
    }

    @Test
    @DisplayName("예매 오픈 안내는 7일 전, 하루 전 09:00 과 1시간 전 주기에 각각 한 번씩만 나간다")
    void timeline_concertOpen_firesOncePerPhase() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 12, 25, 20, 0));
        LocalDateTime openAt = LocalDateTime.of(2026, 10, 4, 20, 0);
        ReflectionTestUtils.setField(concert, "openAt", openAt);
        em.flush();
        subscribeMany(concert, AlarmType.CONCERT_OPEN, 2);
        List<Fire> fires = new ArrayList<>();

        fires.addAll(tick(LocalDateTime.of(2026, 9, 27, 8, 55), LocalDateTime.of(2026, 9, 27, 10, 10)));
        fires.addAll(tick(LocalDateTime.of(2026, 10, 3, 8, 55), LocalDateTime.of(2026, 10, 3, 10, 10)));
        fires.addAll(tick(LocalDateTime.of(2026, 10, 4, 18, 55), LocalDateTime.of(2026, 10, 4, 20, 10)));

        assertThat(firesOf(fires, "CONCERT_OPEN")).containsExactly(
                new Fire("CONCERT_OPEN", LocalDateTime.of(2026, 9, 27, 9, 0), 2),
                new Fire("CONCERT_OPEN", LocalDateTime.of(2026, 10, 3, 9, 0), 2),
                new Fire("CONCERT_OPEN", LocalDateTime.of(2026, 10, 4, 19, 0), 2));
    }

    @Test
    @DisplayName("양도 매물 알림은 마켓 오픈 08:00 주기에 알림을 신청한 회원마다 한 번만 나가고, 이튿날 다시 나간다")
    void timeline_marketNewListing_firesOncePerDay() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 12, 25, 20, 0));
        listing(concert, LocalDateTime.of(2026, 9, 19, 12, 0));
        listing(concert, LocalDateTime.of(2026, 9, 20, 12, 0));
        subscribeMany(concert, AlarmType.MARKET_LISTING, 2);
        List<Fire> fires = new ArrayList<>();

        fires.addAll(tick(LocalDateTime.of(2026, 9, 20, 7, 55), LocalDateTime.of(2026, 9, 20, 9, 10)));
        fires.addAll(tick(LocalDateTime.of(2026, 9, 21, 7, 55), LocalDateTime.of(2026, 9, 21, 9, 10)));

        assertThat(firesOf(fires, "MARKET_NEW_LISTING")).containsExactly(
                new Fire("MARKET_NEW_LISTING", LocalDateTime.of(2026, 9, 20, 8, 0), 2),
                new Fire("MARKET_NEW_LISTING", LocalDateTime.of(2026, 9, 21, 8, 0), 2));
    }

    @Test
    @DisplayName("서버가 알림 시각에 내려가 있다 보정 구간 안에서 돌아오면 돌아온 첫 주기에 한 번 나간다")
    void timeline_outageWithinCatchUp_sendsOnFirstTickBack() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 20, 20, 0));
        holdMany(concert, 2);

        // 18:00 알림 시각부터 18:40 까지 주기가 없다. 18:41 에 돌아온다.
        List<Fire> fires = new ArrayList<>();
        fires.addAll(tick(LocalDateTime.of(2026, 9, 20, 17, 50), LocalDateTime.of(2026, 9, 20, 17, 59)));
        fires.addAll(tick(LocalDateTime.of(2026, 9, 20, 18, 41), LocalDateTime.of(2026, 9, 20, 20, 0)));

        assertThat(firesOf(fires, "ENTRY_OPEN"))
                .containsExactly(new Fire("ENTRY_OPEN", LocalDateTime.of(2026, 9, 20, 18, 41), 2));
    }

    // ---------------------------------------------------------------- 헬퍼

    /** 두 시각 사이를 1분씩 실제 스케줄러로 돌리고, 알림이 새로 저장된 주기만 모은다. */
    private List<Fire> tick(LocalDateTime from, LocalDateTime toInclusive) {
        List<Fire> fires = new ArrayList<>();
        for (LocalDateTime t = from; !t.isAfter(toInclusive); t = t.plusMinutes(1)) {
            for (SweepResult result : scheduler.runOnce(t)) {
                assertThat(result.failed()).as("%s @ %s", result.name(), t).isFalse();
                if (result.recorded() > 0) {
                    fires.add(new Fire(result.name(), t, result.recorded()));
                }
            }
        }
        return fires;
    }

    private static List<Fire> firesOf(List<Fire> fires, String sweepName) {
        return fires.stream().filter(fire -> fire.sweep().equals(sweepName)).toList();
    }

    private static int recordedBy(List<SweepResult> results, String sweepName) {
        return results.stream().filter(r -> r.name().equals(sweepName)).findFirst().orElseThrow().recorded();
    }

    /** 알림이 새로 저장된 주기 하나. */
    private record Fire(String sweep, LocalDateTime tick, int recorded) {
    }

    private List<Long> notifiedMembers(String dedupKey) {
        return jdbc.queryForList("select member_id from notification where dedup_key = ?", Long.class, dedupKey);
    }

    private long count(Member member) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, member.getId());
    }

    private void holdMany(Concert concert, int count) {
        for (int i = 0; i < count; i++) {
            holdTicket(member(), concert);
        }
    }

    private void subscribeMany(Concert concert, AlarmType type, int count) {
        for (int i = 0; i < count; i++) {
            alarmRepository.save(ConcertAlarm.builder().member(member()).concert(concert).type(type).build());
        }
    }

    /** 예매하고 발행까지 끝난 티켓. 좌석은 테스트 안에서 겹치지 않게 하나씩 쓴다. */
    private Ticket holdTicket(Member member, Concert concert) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert).member(member).seat(seats.get(nextSeat++)).build());
        Ticket ticket = ticketRepository.save(Ticket.builder().reservation(reservation).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
    }

    /** 같은 티켓에 매물을 열고 바로 체결시킨다. 서비스를 거치지 않는 이유는 소유자 판정만 보면 되기 때문이다. */
    private void trade(Ticket ticket, Member seller, Member buyer, LocalDateTime tradedAt) {
        ticketRepository.findById(ticket.getId()).orElseThrow().markListed();
        TicketListing listing = ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(), seller.getId(), ticket.getReservation().getConcert(), section,
                ticket.getReservation().getSeat().getSeatNo(), ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L, SEAT_PRICE, tradedAt.minusHours(1)));
        em.flush();
        ticketListingRepository.markSoldIfListed(listing.getId(), tradedAt);
        TicketListing sold = ticketListingRepository.findById(listing.getId()).orElseThrow();
        TicketTrade trade = TicketTrade.record(sold, buyer.getId(), tradedAt);
        trade.confirm();
        ticketTradeRepository.save(trade);
        org.assertj.core.api.Assertions.assertThat(ticketRepository.transferOwnershipIfListed(
                ticket.getId(), seller.getId(), buyer.getId(), tradedAt)).isEqualTo(1);
        em.flush();
    }

    /** 새 판매자가 티켓을 가진 채 매물을 올린다. */
    private void listing(Concert concert, LocalDateTime listedAt) {
        Member seller = member();
        Ticket ticket = holdTicket(seller, concert);
        ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(), seller.getId(), concert, section,
                ticket.getReservation().getSeat().getSeatNo(), ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L, SEAT_PRICE, listedAt));
    }

    /** 상태는 리플렉션으로 넣는다. 공연은 생성 시 SCHEDULED 로 고정되고 상태를 옮기는 메서드가 없다. */
    private Concert concert(String title, LocalDateTime start) {
        Concert concert = concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(start)
                .endDate(start.plusHours(3))
                .openAt(start.minusDays(60))
                .venue(venue)
                .build());
        ReflectionTestUtils.setField(concert, "status", ConcertStatus.ON_SALE);
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
