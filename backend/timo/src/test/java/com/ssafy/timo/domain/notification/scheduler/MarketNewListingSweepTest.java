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
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.wish.entity.ConcertWish;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.config.transfer.MarketHoursProperties;
import com.ssafy.timo.global.config.notification.NotificationProperties;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.math.BigInteger;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.LocalTime;
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
 * 새 양도 매물 알림이 마켓 오픈 시각에, 어제 올라온 매물만 기준으로, 찜한 사람에게 하루 한 건씩 나가는지 실제
 * MySQL 로 확인한다.
 *
 * <p>이 알림은 다른 셋과 조건의 모양이 달라 경계가 두 가지다. 지금이 발송 시각의 보정 구간 안인가와, 매물이
 * 어제 00:00 부터 오늘 00:00 사이에 등록됐는가. 둘 다 초 단위로 본다. 마켓 오픈 시각은 설정({@code 08:00})의
 * 실제 값을 쓴다.
 */
@IntegrationTest
class MarketNewListingSweepTest {

    /** 마켓이 열리는 시각. 모든 테스트의 기본 기준 시각이다. */
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 8, 0);

    /** 기준 시각의 "어제" 한낮. 새 매물이다. */
    private static final LocalDateTime YESTERDAY_NOON = LocalDateTime.of(2026, 9, 19, 12, 0);

    private static final int SEAT_PRICE = 150_000;

    @Autowired
    private MarketNewListingSweep sweep;

    @Autowired
    private TicketListingRepository listingRepository;

    @Autowired
    private ConcertWishRepository wishRepository;

    @Autowired
    private TicketOwnerReader ticketOwnerReader;

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private ConcertRepository concertRepository;

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

    @Test
    @DisplayName("공연 하나에 새 매물이 올라오면 찜한 회원에게 그 공연으로 가는 알림이 규약대로 저장된다")
    void singleConcert_notifiesWisherWithConcertLink() {
        Concert concert = concert("로이킴 콘서트", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(concert, YESTERDAY_NOON);
        Member wisher = wish(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(1);
        Map<String, Object> row = jdbc.queryForMap(
                "select body, type, link_type, link_id, dedup_key from notification where member_id = ?",
                wisher.getId());
        assertThat(row.get("body")).isEqualTo("로이킴 콘서트 양도 매물이 올라왔어요");
        assertThat(row.get("type")).isEqualTo("MARKET_NEW_LISTING");
        assertThat(row.get("link_type")).isEqualTo("CONCERT");
        assertThat(((Number) row.get("link_id")).longValue()).isEqualTo(concert.getId());
        assertThat(row.get("dedup_key")).isEqualTo("MARKET_NEW_LISTING:2026-09-20");
    }

    @Test
    @DisplayName("찜한 공연이 여럿이면 한 통에 목록으로 묶어 마켓으로 보내고, 공연일이 임박한 순으로 나열한다")
    void multipleConcerts_areCombinedInOneNotificationSoonestFirst() {
        Concert later = concert("나중 공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        Concert sooner = concert("임박 공연", NOW.plusDays(5), ConcertStatus.ON_SALE);
        listing(later, YESTERDAY_NOON);
        listing(sooner, YESTERDAY_NOON);
        Member wisher = wish(later, sooner);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).as("회원 한 명에게 한 건").isEqualTo(1);
        assertThat(bodyOf(wisher)).isEqualTo("찜한 공연 2건에 양도 매물이 올라왔어요\n· 임박 공연\n· 나중 공연");
        Map<String, Object> row = jdbc.queryForMap(
                "select link_type, link_id from notification where member_id = ?", wisher.getId());
        assertThat(row.get("link_type")).isEqualTo("MARKET");
        assertThat(row.get("link_id")).isNull();
    }

    @Test
    @DisplayName("공연이 네 개 이상이면 세 개만 나열하고 나머지는 외 N건으로 접는다")
    void moreThanThree_isFoldedIntoRest() {
        List<Concert> concerts = new ArrayList<>();
        for (int i = 1; i <= 4; i++) {
            Concert concert = concert("공연" + i, NOW.plusDays(i), ConcertStatus.ON_SALE);
            listing(concert, YESTERDAY_NOON);
            concerts.add(concert);
        }
        Member wisher = wish(concerts.toArray(Concert[]::new));

        sweep.run(NOW, 500);

        assertThat(bodyOf(wisher)).isEqualTo(
                "찜한 공연 4건에 양도 매물이 올라왔어요\n· 공연1\n· 공연2\n· 공연3\n· 외 1건");
    }

    @ParameterizedTest(name = "마켓 오픈 시각에서 {0}초 지난 시점이면 대상 {1}")
    @CsvSource({
            "-1, false",    // 오픈 1초 전. 아직 이르다
            "0, true",      // 정확히 오픈 시각이다
            "3600, true",   // 보정 구간의 끝이다
            "3601, false"   // 보정 구간을 1초 넘겨 놓쳤다
    })
    @DisplayName("발송 시각의 시간 창 경계를 초 단위로 지킨다")
    void sendTimeWindowBoundaries(long secondsAfterOpen, boolean expectedNotified) {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(concert, YESTERDAY_NOON);
        wish(concert);

        int recorded = sweep.run(NOW.plusSeconds(secondsAfterOpen), 500);

        assertThat(recorded).isEqualTo(expectedNotified ? 1 : 0);
    }

    @ParameterizedTest(name = "매물이 {0} 에 등록됐으면 새 매물 {1}")
    @CsvSource({
            "2026-09-18T23:59:59, false",  // 그저께 마지막 1초
            "2026-09-19T00:00:00, true",   // 어제 시작 정각
            "2026-09-19T23:59:59, true",   // 어제 마지막 1초
            "2026-09-20T00:00:00, false",  // 오늘 시작 정각. 아직 마켓에 안 보이던 매물이다
            "2026-09-20T10:00:00, false"   // 오늘 낮
    })
    @DisplayName("새 매물은 어제 00:00 이상 오늘 00:00 미만에 등록된 것이다")
    void listedDateBoundaries(LocalDateTime listedAt, boolean expectedNew) {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(concert, listedAt);
        wish(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(expectedNew ? 1 : 0);
    }

    @Test
    @DisplayName("그 사이 팔렸거나 취소된 매물은 새 매물이 아니다")
    void soldOrCanceledListings_areNotNew() {
        Concert sold = concert("팔린 공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        Concert canceled = concert("취소된 매물 공연", NOW.plusDays(11), ConcertStatus.ON_SALE);
        listing(sold, YESTERDAY_NOON).markStatus(ListingStatus.SOLD);
        listing(canceled, YESTERDAY_NOON).markStatus(ListingStatus.CANCELED);
        em.flush();
        wish(sold, canceled);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("취소된 공연과 종료된 공연은 제외하고, 매진된 공연은 포함한다")
    void canceledAndClosedConcertsAreExcluded_soldOutIsNot() {
        Concert canceled = concert("취소된 공연", NOW.plusDays(10), ConcertStatus.CANCELED);
        Concert closed = concert("종료된 공연", NOW.plusDays(11), ConcertStatus.CLOSED);
        Concert soldOut = concert("매진 공연", NOW.plusDays(12), ConcertStatus.SOLD_OUT);
        listing(canceled, YESTERDAY_NOON);
        listing(closed, YESTERDAY_NOON);
        listing(soldOut, YESTERDAY_NOON);
        Member wisher = wish(canceled, closed, soldOut);

        sweep.run(NOW, 500);

        assertThat(bodyOf(wisher)).isEqualTo("매진 공연 양도 매물이 올라왔어요");
    }

    @Test
    @DisplayName("시작이 2시간 이내인 공연은 제외하고, 1초라도 넘으면 포함한다")
    void concertStartingWithinTwoHours_isExcluded() {
        Concert tooSoon = concert("곧 시작", NOW.plusHours(2), ConcertStatus.ON_SALE);
        Concert justEnough = concert("여유 있는 공연", NOW.plusHours(2).plusSeconds(1), ConcertStatus.ON_SALE);
        listing(tooSoon, YESTERDAY_NOON);
        listing(justEnough, YESTERDAY_NOON);
        Member wisher = wish(tooSoon, justEnough);

        sweep.run(NOW, 500);

        assertThat(bodyOf(wisher)).isEqualTo("여유 있는 공연 양도 매물이 올라왔어요");
    }

    @Test
    @DisplayName("자기 매물의 판매자와 그 공연 티켓을 이미 가진 회원은 받지 않는다")
    void sellerAndTicketHolder_areNotNotified() {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        Member seller = listing(concert, YESTERDAY_NOON).seller();
        Member holder = member();
        holdTicket(holder, concert);
        Member ordinary = member();
        wish(seller, concert);
        wish(holder, concert);
        wish(ordinary, concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(1);
        assertThat(count(seller)).isZero();
        assertThat(count(holder)).isZero();
        assertThat(count(ordinary)).isEqualTo(1);
    }

    @Test
    @DisplayName("보유자 판정이 판매자를 놓치더라도 자기 매물의 판매자는 알림을 받지 않는다")
    void seller_isExcludedEvenWhenHolderJudgmentMissesThem() {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        // 티켓은 다른 회원의 것이다. 이 판매자는 보유자 판정에 잡히지 않는다.
        Ticket someoneElsesTicket = holdTicket(member(), concert);
        Member seller = member();
        listingRepository.saveAndFlush(TicketListing.open(
                someoneElsesTicket.getId(), seller.getId(), concert, section,
                someoneElsesTicket.getReservation().getSeat().getSeatNo(),
                someoneElsesTicket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L, SEAT_PRICE, YESTERDAY_NOON));
        wish(seller, concert);
        Member ordinary = wish(concert);

        sweep.run(NOW, 500);

        assertThat(count(seller)).isZero();
        assertThat(count(ordinary)).isEqualTo(1);
    }

    @Test
    @DisplayName("이미 티켓을 가진 공연은 목록에서 빠지고 나머지 공연만 알린다")
    void holderOfOneConcert_isNotifiedAboutTheOthersOnly() {
        Concert owned = concert("가진 공연", NOW.plusDays(5), ConcertStatus.ON_SALE);
        Concert wanted = concert("원하는 공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(owned, YESTERDAY_NOON);
        listing(wanted, YESTERDAY_NOON);
        Member member = member();
        holdTicket(member, owned);
        wish(member, owned);
        wish(member, wanted);

        sweep.run(NOW, 500);

        assertThat(bodyOf(member)).isEqualTo("원하는 공연 양도 매물이 올라왔어요");
        Map<String, Object> row = jdbc.queryForMap(
                "select link_type, link_id from notification where member_id = ?", member.getId());
        assertThat(row.get("link_type")).as("남은 공연이 하나이면 그 공연으로 간다").isEqualTo("CONCERT");
        assertThat(((Number) row.get("link_id")).longValue()).isEqualTo(wanted.getId());
    }

    @Test
    @DisplayName("찜하지 않은 회원과 매물이 없는 공연을 찜한 회원은 받지 않는다")
    void nonWishers_areNotNotified() {
        Concert withListing = concert("매물 있는 공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        Concert withoutListing = concert("매물 없는 공연", NOW.plusDays(11), ConcertStatus.ON_SALE);
        listing(withListing, YESTERDAY_NOON);
        Member noWish = member();
        Member wishesOther = wish(withoutListing);

        assertThat(sweep.run(NOW, 500)).isZero();
        assertThat(count(noWish)).isZero();
        assertThat(count(wishesOther)).isZero();
    }

    @Test
    @DisplayName("같은 날 다시 돌거나 보정 구간 안에서 시간이 흘러도 알림은 늘지 않는다")
    void repeatedRuns_doNotDuplicate() {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(concert, YESTERDAY_NOON);
        Member wisher = wish(concert);

        int first = sweep.run(NOW, 500);
        int again = sweep.run(NOW, 500);
        int later = sweep.run(NOW.plusMinutes(30), 500);

        assertThat(first).isEqualTo(1);
        assertThat(again).isZero();
        assertThat(later).isZero();
        assertThat(count(wisher)).isEqualTo(1);
    }

    @Test
    @DisplayName("다음 날 오픈에는 그날 기준의 새 매물로 다시 나가고 키는 날짜별로 다르다")
    void nextDay_sendsAgainWithNewDateKey() {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(concert, YESTERDAY_NOON);
        listing(concert, NOW.plusHours(1)); // 9/20 21:00 등록, 다음 날 기준으로 새 매물이다
        Member wisher = wish(concert);

        sweep.run(NOW, 500);
        int nextDay = sweep.run(NOW.plusDays(1), 500);

        assertThat(nextDay).isEqualTo(1);
        assertThat(jdbc.queryForList("select dedup_key from notification where member_id = ? order by notification_id",
                String.class, wisher.getId()))
                .containsExactly("MARKET_NEW_LISTING:2026-09-20", "MARKET_NEW_LISTING:2026-09-21");
    }

    @Test
    @DisplayName("오픈 시각이 밤늦어 보정 구간이 자정을 넘어도, 자정 뒤 주기가 전날의 발송을 마무리한다")
    void catchUpAcrossMidnight_finishesPreviousDaysSend() {
        MarketNewListingSweep lateOpen = new MarketNewListingSweep(listingRepository, wishRepository,
                ticketOwnerReader, recorder,
                new MarketHoursProperties(LocalTime.of(23, 30), LocalTime.of(23, 59, 59)),
                new NotificationProperties(500, Duration.ofHours(1)));
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        listing(concert, LocalDateTime.of(2026, 9, 19, 12, 0)); // 9/20 발송의 새 매물
        Member wisher = wish(concert);

        assertThat(lateOpen.run(LocalDateTime.of(2026, 9, 21, 0, 31), 500)).as("보정 구간을 넘겼다").isZero();
        assertThat(lateOpen.run(LocalDateTime.of(2026, 9, 21, 0, 10), 500)).as("자정 뒤지만 구간 안이다")
                .isEqualTo(1);
        assertThat(keyOf(wisher)).as("발송일은 전날이다").isEqualTo("MARKET_NEW_LISTING:2026-09-20");
    }

    @Test
    @DisplayName("처리 상한에 닿으면 멈추고 남은 회원은 다음 주기에 이어서 받으며, 여러 공연을 찜한 회원도 한 건이다")
    void limit_countsNotificationsAndContinuesNextRun() {
        Concert first = concert("첫 공연", NOW.plusDays(5), ConcertStatus.ON_SALE);
        Concert second = concert("둘째 공연", NOW.plusDays(6), ConcertStatus.ON_SALE);
        listing(first, YESTERDAY_NOON);
        listing(second, YESTERDAY_NOON);
        List<Member> wishers = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            wishers.add(wish(first, second));
        }

        int run1 = sweep.run(NOW, 2);
        int run2 = sweep.run(NOW.plusMinutes(1), 2);
        int run3 = sweep.run(NOW.plusMinutes(2), 2);
        int run4 = sweep.run(NOW.plusMinutes(3), 2);

        assertThat(List.of(run1, run2, run3, run4)).containsExactly(2, 2, 1, 0);
        assertThat(wishers).allSatisfy(wisher -> assertThat(count(wisher)).isEqualTo(1));
    }

    @Test
    @DisplayName("새 매물이 없으면 0건이다")
    void noNewListings_returnsZero() {
        Concert concert = concert("공연", NOW.plusDays(10), ConcertStatus.ON_SALE);
        wish(concert);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    // ---------------------------------------------------------------- 헬퍼

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

    /** 이 공연들을 새 회원이 찜한다. */
    private Member wish(Concert... concerts) {
        Member member = member();
        wish(member, concerts);
        return member;
    }

    private void wish(Member member, Concert... concerts) {
        for (Concert concert : concerts) {
            wishRepository.save(ConcertWish.builder().member(member).concert(concert).build());
        }
    }

    /** 새 판매자가 티켓을 가진 채 매물을 올린다. */
    private ListingFixture listing(Concert concert, LocalDateTime listedAt) {
        Member seller = member();
        Ticket ticket = holdTicket(seller, concert);
        TicketListing listing = listingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(), seller.getId(), concert, section,
                ticket.getReservation().getSeat().getSeatNo(), ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L, SEAT_PRICE, listedAt));
        return new ListingFixture(listing, seller);
    }

    private record ListingFixture(TicketListing listing, Member seller) {

        /** 상태를 리플렉션으로 바꾼다. 팔림·취소로 가는 서비스 경로를 태우지 않고 상태만 필요해서다. */
        ListingFixture markStatus(ListingStatus status) {
            ReflectionTestUtils.setField(listing, "status", status);
            return this;
        }
    }

    private Ticket holdTicket(Member member, Concert concert) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert).member(member).seat(seats.get(nextSeat++)).build());
        Ticket ticket = ticketRepository.save(Ticket.builder().reservation(reservation).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
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
