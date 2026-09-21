package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.entity.ConcertAlarm;
import com.ssafy.timo.domain.alarm.repository.ConcertAlarmRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.controller.DevNotificationController;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.IntegrationTest;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/**
 * 개발용 수동 트리거를 확인한다.
 *
 * <p>가장 중요한 것은 운영에 이 경로가 없는 것이다. 프로필이 이 컨트롤러를 로컬과 시연에만 올리는지, 그 밖의
 * 환경(여기서는 test)에서는 빈도 경로도 없는지를 본다. 동작은 실제 스케줄러와 DB 로 확인한다. 로컬 프로필은
 * 도커와 시드가 필요해 띄우지 않고, 컨트롤러를 직접 조립한 MockMvc 로 부른다.
 */
@IntegrationTest
class DevNotificationControllerTest {

    private static final String PATH = "/api/v1/dev/notifications/sweep";

    @Autowired
    private ApplicationContext context;

    @Autowired
    private MockMvc contextMvc;

    @Autowired
    private NotificationSweepScheduler scheduler;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private ConcertAlarmRepository alarmRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbc;

    private MockMvc mvc;
    /** 테스트가 지정하는 기준 시각(9월 20일)과 다른 날로 둔다. 같으면 기준 시각을 무시해도 티가 나지 않는다. */
    private final Clock fixedClock =
            Clock.fixed(Instant.parse("2026-03-01T00:00:00Z"), ZoneId.of("Asia/Seoul"));

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new DevNotificationController(scheduler, fixedClock)).build();
    }

    @Test
    @DisplayName("로컬과 시연 프로필에서만 올라오도록 표시되어 있다")
    void controller_isRestrictedToLocalAndDemoProfiles() {
        Profile profile = DevNotificationController.class.getAnnotation(Profile.class);

        assertThat(profile).isNotNull();
        assertThat(profile.value()).containsExactlyInAnyOrder("local", "demo");
    }

    @Test
    @DisplayName("그 밖의 프로필에서는 빈도 경로도 없다")
    void otherProfiles_haveNeitherBeanNorEndpoint() throws Exception {
        assertThat(context.getBeansOfType(DevNotificationController.class)).isEmpty();

        contextMvc.perform(post(PATH)).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("기준 시각을 주면 그 시각인 것처럼 스윕이 돌고 알림이 만들어진다")
    void sweep_withAt_createsNotificationsAsOfThatTime() throws Exception {
        Concert concert = concert("로이킴 콘서트", LocalDateTime.of(2026, 9, 27, 20, 0));
        Member subscriber = subscribe(concert);

        mvc.perform(post(PATH).param("at", "2026-09-20T09:00:00"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.at").value("2026-09-20T09:00:00"))
                .andExpect(jsonPath("$.sweeps", hasSize(4)))
                .andExpect(jsonPath("$.sweeps[?(@.name == 'CONCERT_OPEN')].recorded").value(1))
                .andExpect(jsonPath("$.sweeps[?(@.failed == true)]").isEmpty());

        assertThat(jdbc.queryForObject("select body from notification where member_id = ?", String.class,
                subscriber.getId())).isEqualTo("로이킴 콘서트 예매가 일주일 뒤 시작돼요");
    }

    @Test
    @DisplayName("같은 시각으로 다시 부르면 이번에는 0건이다")
    void sweep_calledTwiceWithSameAt_recordsNothingSecondTime() throws Exception {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0));
        Member subscriber = subscribe(concert);

        mvc.perform(post(PATH).param("at", "2026-09-20T09:00:00")).andExpect(status().isOk());
        mvc.perform(post(PATH).param("at", "2026-09-20T09:00:00"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sweeps[?(@.name == 'CONCERT_OPEN')].recorded").value(0));

        assertThat(jdbc.queryForObject("select count(*) from notification where member_id = ?", Long.class,
                subscriber.getId())).isEqualTo(1);
    }

    @Test
    @DisplayName("기준 시각을 주지 않으면 시계의 현재 시각을 쓴다")
    void sweep_withoutAt_usesClockNow() throws Exception {
        mvc.perform(post(PATH))
                .andExpect(status().isOk())
                // 고정 시계는 UTC 00:00 = 서울 09:00 이다.
                .andExpect(jsonPath("$.at").value("2026-03-01T09:00:00"));
    }

    @Test
    @DisplayName("기준 시각의 형식이 틀리면 400 이다")
    void sweep_withMalformedAt_isBadRequest() throws Exception {
        mvc.perform(post(PATH).param("at", "내일 아침")).andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("스윕이 만든 알림은 예매 오픈 안내 종류로 저장된다")
    void sweep_savesNotificationOfExpectedType() throws Exception {
        Concert concert = concert("공연", LocalDateTime.of(2026, 9, 27, 20, 0));
        Member subscriber = subscribe(concert);

        mvc.perform(post(PATH).param("at", "2026-09-20T09:00:00")).andExpect(status().isOk());

        assertThat(jdbc.queryForList("select type from notification where member_id = ?", String.class,
                subscriber.getId())).containsExactly("CONCERT_OPEN_REMINDER");
    }

    private Concert concert(String title, LocalDateTime openAt) {
        Venue venue = venueRepository.save(Venue.builder()
                .name("공연장-" + UUID.randomUUID().toString().substring(0, 6))
                .address("서울시 송파구").totalSeatCount(5000).build());
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(openAt)
                .startDate(openAt.plusDays(30))
                .endDate(openAt.plusDays(30).plusHours(3))
                .venue(venue)
                .build());
    }

    private Member subscribe(Concert concert) {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        Member member = memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());
        alarmRepository.save(ConcertAlarm.builder().member(member).concert(concert).type(AlarmType.CONCERT_OPEN).build());
        return member;
    }
}
