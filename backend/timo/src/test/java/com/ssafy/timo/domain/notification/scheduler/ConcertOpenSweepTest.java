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
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.wish.entity.ConcertWish;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.config.NotificationProperties;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 예매 오픈 안내가 정해진 날짜와 시각에, 찜한 사람에게만, 한 번씩 나가는지 실제 MySQL 로 확인한다.
 *
 * <p>7일 전과 하루 전은 오픈 시각이 아니라 <b>오픈 날짜</b>의 09:00 에 나간다. 그래서 오픈이 새벽 0시 반이든
 * 밤 11시 59분이든 같은 아침에 나가는지를 따로 본다. 시간 창의 경계는 초 단위로 본다.
 */
@IntegrationTest
class ConcertOpenSweepTest {

    /** 7일 전 알림의 시각이자 하루 전 알림의 시각. 9월 27일 오픈은 이날 09:00 에 7일 전이 나간다. */
    private static final LocalDateTime SEVEN_DAYS_BEFORE_SEND = LocalDateTime.of(2026, 9, 20, 9, 0);

    /** 모든 테스트의 기본 기준 시각. */
    private static final LocalDateTime NOW = SEVEN_DAYS_BEFORE_SEND;

    @Autowired
    private ConcertOpenSweep sweep;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private ConcertWishRepository wishRepository;

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private EntityManager em;

    @Autowired
    private JdbcTemplate jdbc;

    private Venue venue;

    @BeforeEach
    void setUp() {
        venue = venueRepository.save(Venue.builder()
                .name("공연장-" + UUID.randomUUID().toString().substring(0, 6))
                .address("서울시 송파구")
                .totalSeatCount(5000)
                .build());
    }

    @Test
    @DisplayName("7일 전: 오픈 날짜의 7일 전 09:00 에 찜한 회원에게 규약대로 저장된다")
    void sevenDaysBefore_notifiesWisherWithContractFields() {
        Concert concert = concert("로이킴 콘서트", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
        Member wisher = wish(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(1);
        Map<String, Object> row = jdbc.queryForMap(
                "select body, type, link_type, link_id, dedup_key from notification where member_id = ?",
                wisher.getId());
        assertThat(row.get("body")).isEqualTo("로이킴 콘서트 예매가 일주일 뒤 시작돼요");
        assertThat(row.get("type")).isEqualTo("CONCERT_OPEN_REMINDER");
        assertThat(row.get("link_type")).isEqualTo("CONCERT");
        assertThat(((Number) row.get("link_id")).longValue()).isEqualTo(concert.getId());
        assertThat(row.get("dedup_key")).isEqualTo("CONCERT_OPEN_D7:concert=" + concert.getId());
    }

    @Test
    @DisplayName("1일 전: 오픈 날짜의 하루 전 09:00 에 나간다")
    void oneDayBefore_notifiesAt0900() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 21, 20, 0), ConcertStatus.SCHEDULED);
        Member wisher = wish(concert);

        assertThat(sweep.run(NOW, 500)).isEqualTo(1);

        assertThat(bodyOf(wisher)).isEqualTo("공연 예매가 내일 시작돼요");
        assertThat(keyOf(wisher)).isEqualTo("CONCERT_OPEN_D1:concert=" + concert.getId());
    }

    @Test
    @DisplayName("1시간 전: 오픈 시각의 1시간 전에 나간다")
    void oneHourBefore_notifies() {
        Concert concert = concert("공연", NOW.plusHours(1), ConcertStatus.SCHEDULED);
        Member wisher = wish(concert);

        assertThat(sweep.run(NOW, 500)).isEqualTo(1);

        assertThat(bodyOf(wisher)).isEqualTo("공연 예매 시작까지 1시간 남았어요");
        assertThat(keyOf(wisher)).isEqualTo("CONCERT_OPEN_H1:concert=" + concert.getId());
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
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
        wish(concert);

        int recorded = sweep.run(SEVEN_DAYS_BEFORE_SEND.plusSeconds(secondsAfterSend), 500);

        assertThat(recorded).isEqualTo(expectedNotified ? 1 : 0);
    }

    @ParameterizedTest(name = "오픈이 지금부터 {0}초 뒤이면 1시간 전 알림 대상 {1}")
    @CsvSource({
            "3601, false",  // 알림 시각이 1초 뒤다. 아직 이르다
            "3600, true",   // 알림 시각이 정확히 지금이다
            "1, true",      // 보정 구간 끝에 가깝다. 늦게라도 나간다
            "0, false"      // 이미 열렸다
    })
    @DisplayName("1시간 전 알림의 시간 창 경계를 초 단위로 지킨다")
    void oneHourBefore_windowBoundaries(long secondsUntilOpen, boolean expectedNotified) {
        Concert concert = concert("공연", NOW.plusSeconds(secondsUntilOpen), ConcertStatus.SCHEDULED);
        wish(concert);

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(expectedNotified ? 1 : 0);
    }

    @ParameterizedTest(name = "오픈이 {0} 이어도 7일 전 알림은 같은 날 09:00 에 나간다")
    @CsvSource({"2026-09-27T00:30:00", "2026-09-27T12:00:00", "2026-09-27T23:59:00"})
    @DisplayName("7일 전은 오픈 시각이 아니라 오픈 날짜를 기준으로 09:00 에 나간다")
    void sevenDaysBefore_usesOpenDateNotOpenTime(LocalDateTime openAt) {
        Concert concert = concert("공연", openAt, ConcertStatus.SCHEDULED);
        wish(concert);

        assertThat(sweep.run(SEVEN_DAYS_BEFORE_SEND.minusSeconds(1), 500)).as("09:00 전").isZero();
        assertThat(sweep.run(SEVEN_DAYS_BEFORE_SEND, 500)).as("09:00 정각").isEqualTo(1);
    }

    @Test
    @DisplayName("오픈 당일 09:00 에는 알림이 없다")
    void openDayMorning_hasNoNotification() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 20, 20, 0), ConcertStatus.SCHEDULED);
        wish(concert);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("취소된 공연은 알림이 없다")
    void canceledConcert_isExcluded() {
        Concert concert = concert("취소된 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.CANCELED);
        wish(concert);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("찜한 회원에게만 가고, 찜하지 않은 회원과 다른 공연을 찜한 회원은 받지 않는다")
    void onlyWishersOfThatConcert_areNotified() {
        Concert target = concert("대상 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
        Concert other = concert("다른 공연", LocalDateTime.of(2026, 12, 25, 20, 0), ConcertStatus.SCHEDULED);
        Member first = wish(target);
        Member second = wish(target);
        Member wishesOther = wish(other);
        member(); // 아무것도 찜하지 않은 회원

        int recorded = sweep.run(NOW, 500);

        assertThat(recorded).isEqualTo(2);
        assertThat(notifiedMembers("CONCERT_OPEN_D7", target))
                .containsExactlyInAnyOrder(first.getId(), second.getId());
        assertThat(count(wishesOther)).isZero();
    }

    @Test
    @DisplayName("같은 주기를 다시 돌거나 창 안에서 시간이 흘러도 알림은 늘지 않는다")
    void repeatedRuns_doNotDuplicate() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
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
    @DisplayName("같은 공연의 7일 전, 1일 전, 1시간 전은 각자의 키로 따로 나간다")
    void eachPhase_isAnIndependentNotification() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
        Member wisher = wish(concert);

        sweep.run(LocalDateTime.of(2026, 9, 20, 9, 0), 500);
        sweep.run(LocalDateTime.of(2026, 9, 26, 9, 0), 500);
        sweep.run(LocalDateTime.of(2026, 9, 27, 19, 0), 500);

        assertThat(jdbc.queryForList("select dedup_key from notification where member_id = ? order by notification_id",
                String.class, wisher.getId()))
                .containsExactly(
                        "CONCERT_OPEN_D7:concert=" + concert.getId(),
                        "CONCERT_OPEN_D1:concert=" + concert.getId(),
                        "CONCERT_OPEN_H1:concert=" + concert.getId());
    }

    @Test
    @DisplayName("서버가 오래 내려가 있었어도 보정 구간이 길면 놓친 시점을 모두 보낸다")
    void longOutage_sendsEveryMissedPhaseWithinCatchUp() {
        ConcertOpenSweep weekLong = withCatchUp(Duration.ofDays(7));
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 21, 20, 0), ConcertStatus.SCHEDULED);
        Member wisher = wish(concert);

        // 7일 전(9/14 09:00)과 1일 전(9/20 09:00) 알림 시각이 모두 지났고 아직 열리지 않았다.
        int recorded = weekLong.run(LocalDateTime.of(2026, 9, 20, 10, 0), 500);

        assertThat(recorded).isEqualTo(2);
        assertThat(jdbc.queryForList("select dedup_key from notification where member_id = ?", String.class,
                wisher.getId()))
                .containsExactlyInAnyOrder(
                        "CONCERT_OPEN_D7:concert=" + concert.getId(),
                        "CONCERT_OPEN_D1:concert=" + concert.getId());
    }

    @Test
    @DisplayName("보정 구간이 길어도 이미 열린 공연에는 어떤 알림도 보내지 않는다")
    void alreadyOpened_isNeverNotified() {
        ConcertOpenSweep longCatchUp = withCatchUp(Duration.ofHours(5));
        Concert concert = concert("이미 열린 공연", NOW.minusHours(1), ConcertStatus.SCHEDULED);
        wish(concert);

        assertThat(longCatchUp.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("오픈이 한참 뒤인 공연은 알림 시각이 오지 않았으니 보내지 않는다")
    void farFutureOpen_isNotNotified() {
        Concert concert = concert("먼 공연", NOW.plusDays(30), ConcertStatus.SCHEDULED);
        wish(concert);

        assertThat(sweep.run(NOW, 500)).isZero();
    }

    @Test
    @DisplayName("처리 상한에 닿으면 멈추고, 남은 사람은 다음 주기에 이어서 받으며 중복은 없다")
    void limit_stopsAndContinuesNextRun() {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
        List<Member> wishers = wishMany(concert, 5);

        int first = sweep.run(NOW, 2);
        int second = sweep.run(NOW.plusMinutes(1), 2);
        int third = sweep.run(NOW.plusMinutes(2), 2);
        int fourth = sweep.run(NOW.plusMinutes(3), 2);

        assertThat(List.of(first, second, third, fourth)).containsExactly(2, 2, 1, 0);
        assertThat(notifiedMembers("CONCERT_OPEN_D7", concert))
                .containsExactlyInAnyOrderElementsOf(wishers.stream().map(Member::getId).toList());
    }

    @Test
    @DisplayName("상한은 공연과 시점을 넘나들며 하나로 센다")
    void limit_isSharedAcrossConcertsAndPhases() {
        Concert sevenDay = concert("7일 전 공연", LocalDateTime.of(2026, 9, 27, 20, 0), ConcertStatus.SCHEDULED);
        Concert oneDay = concert("1일 전 공연", LocalDateTime.of(2026, 9, 21, 20, 0), ConcertStatus.SCHEDULED);
        wishMany(sevenDay, 2);
        wishMany(oneDay, 2);

        assertThat(sweep.run(NOW, 3)).isEqualTo(3);
        assertThat(sweep.run(NOW.plusMinutes(1), 3)).isEqualTo(1);
    }

    // ---------------------------------------------------------------- 헬퍼

    private ConcertOpenSweep withCatchUp(Duration catchUp) {
        return new ConcertOpenSweep(concertRepository, wishRepository, recorder,
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

    private Member wish(Concert concert) {
        Member member = member();
        wishRepository.save(ConcertWish.builder().member(member).concert(concert).build());
        return member;
    }

    private List<Member> wishMany(Concert concert, int count) {
        List<Member> members = new ArrayList<>();
        for (int i = 0; i < count; i++) {
            members.add(wish(concert));
        }
        return members;
    }

    /** 상태는 리플렉션으로 넣는다. 공연은 생성 시 SCHEDULED 로 고정되고 상태를 옮기는 메서드가 없다. */
    private Concert concert(String title, LocalDateTime openAt, ConcertStatus status) {
        Concert concert = concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(openAt)
                .startDate(openAt.plusDays(30))
                .endDate(openAt.plusDays(30).plusHours(3))
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
