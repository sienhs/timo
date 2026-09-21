package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.entity.ConcertAlarm;
import com.ssafy.timo.domain.alarm.repository.ConcertAlarmRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.entity.PushDevice;
import com.ssafy.timo.domain.notification.entity.PushPlatform;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import com.ssafy.timo.domain.notification.scheduler.ConcertOpenSweep;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweep;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler.SweepResult;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.NotificationRecorder.Draft;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.config.notification.NotificationProperties;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushNotificationSender;
import com.ssafy.timo.global.firebase.PushResult;
import com.ssafy.timo.global.firebase.PushTarget;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * 스윕이 알림을 저장하고, 커밋된 뒤에 푸시가 나가는 전체 흐름을 실제 커밋으로 확인한다.
 *
 * <p>조각은 따로 확인했다. 스윕이 무엇을 저장하는지, 저장 뒤에 이벤트가 나가는지, 이벤트가 푸시가 되는지. 여기서는
 * 그것이 한 줄로 이어지는지를 본다. 특히 스윕 하나가 실패해도 그 스윕이 저장하던 알림은 되돌아가 푸시도
 * 나가지 않고, 다른 스윕의 푸시는 정상으로 나가는지를 본다.
 *
 * <p>커밋 이후 단계는 롤백되는 테스트 트랜잭션 안에서는 오지 않으므로 테스트에 {@code @Transactional} 을 붙이지
 * 않고 직접 커밋한 뒤 만든 행을 지운다. 발송기를 {@code @MockitoBean} 으로 바꾸므로 이 클래스만 별도
 * 컨텍스트를 띄운다.
 */
@SpringBootTest
@ActiveProfiles("test")
class NotificationSweepPushPipelineTest {

    /** 9월 27일 20시 오픈의 7일 전 알림이 나가는 시각. */
    private static final LocalDateTime SEND_TIME = LocalDateTime.of(2026, 9, 20, 9, 0);

    @MockitoBean
    private PushNotificationSender sender;

    @Autowired
    private NotificationSweepScheduler scheduler;

    @Autowired
    private ConcertOpenSweep concertOpenSweep;

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private Clock clock;

    @Autowired
    private NotificationProperties properties;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private PushDeviceRepository pushDeviceRepository;

    @Autowired
    private ConcertAlarmRepository alarmRepository;

    @Autowired
    private JdbcTemplate jdbc;

    private Venue venue;
    private Concert concert;
    private Member subscriber;
    private String subscriberPhoneToken;
    private String subscriberTabletToken;
    private Member bystander;
    private String bystanderToken;

    @BeforeEach
    void setUp() {
        String unique = UUID.randomUUID().toString().substring(0, 8);
        venue = venueRepository.save(Venue.builder()
                .name("공연장-" + unique.substring(0, 6)).address("서울시 송파구").totalSeatCount(5000).build());
        concert = concertRepository.save(Concert.builder()
                .title("로이킴 콘서트")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .openAt(LocalDateTime.of(2026, 9, 27, 20, 0))
                .startDate(LocalDateTime.of(2026, 10, 27, 20, 0))
                .endDate(LocalDateTime.of(2026, 10, 27, 23, 0))
                .venue(venue)
                .build());

        subscriber = member();
        subscriberPhoneToken = "phone-" + unique;
        subscriberTabletToken = "tablet-" + unique;
        device(subscriber, subscriberPhoneToken);
        device(subscriber, subscriberTabletToken);
        alarmRepository.save(ConcertAlarm.builder().member(subscriber).concert(concert).type(AlarmType.CONCERT_OPEN).build());

        bystander = member();
        bystanderToken = "bystander-" + unique;
        device(bystander, bystanderToken);

        doAnswer(invocation -> {
            List<PushTarget> targets = invocation.getArgument(0);
            return targets.stream().map(target -> PushResult.sent(target.token())).toList();
        }).when(sender).sendEach(anyList(), any());
    }

    @AfterEach
    void cleanUp() {
        for (Member member : List.of(subscriber, bystander)) {
            jdbc.update("delete from notification where member_id = ?", member.getId());
            jdbc.update("delete from push_device where member_id = ?", member.getId());
        }
        jdbc.update("delete from concert_alarm where concert_id = ?", concert.getId());
        jdbc.update("delete from concert where concert_id = ?", concert.getId());
        jdbc.update("delete from venue where venue_id = ?", venue.getId());
        for (Member member : List.of(subscriber, bystander)) {
            jdbc.update("delete from member where member_id = ?", member.getId());
        }
    }

    @Test
    @DisplayName("스윕이 알림을 저장하고 커밋되면, 그 회원의 모든 기기에 알림함과 같은 본문의 푸시가 나간다")
    void sweep_thenCommit_pushesToEveryDeviceWithInboxBody() {
        // 이 회원은 안 읽은 알림이 이미 하나 있다. 푸시의 안 읽은 개수는 새 알림을 포함해 둘이어야 한다.
        jdbc.update("""
                insert into notification (member_id, type, body, link_type, link_id, dedup_key, created_at, updated_at)
                values (?, 'ENTRY_OPEN', '예전 알림', 'CONCERT', 1, 'OLD:1', ?, ?)
                """, subscriber.getId(), LocalDateTime.of(2026, 9, 1, 9, 0), LocalDateTime.of(2026, 9, 1, 9, 0));

        List<SweepResult> results = scheduler.runOnce(SEND_TIME);

        assertThat(results).filteredOn(r -> r.name().equals("CONCERT_OPEN")).singleElement()
                .satisfies(r -> assertThat(r.recorded()).isEqualTo(1));

        ArgumentCaptor<List<PushTarget>> targets = targetCaptor();
        ArgumentCaptor<PushDelivery> delivery = ArgumentCaptor.forClass(PushDelivery.class);
        verify(sender, timeout(5000)).sendEach(targets.capture(), delivery.capture());

        String inboxBody = jdbc.queryForObject(
                "select body from notification where member_id = ? and type = 'CONCERT_OPEN_REMINDER'",
                String.class, subscriber.getId());
        Long inboxId = jdbc.queryForObject(
                "select notification_id from notification where member_id = ? and type = 'CONCERT_OPEN_REMINDER'",
                Long.class, subscriber.getId());
        assertThat(inboxBody).isEqualTo("로이킴 콘서트 예매가 일주일 뒤 시작돼요");
        assertThat(targets.getValue()).extracting(PushTarget::token)
                .containsExactlyInAnyOrder(subscriberPhoneToken, subscriberTabletToken);
        assertThat(targets.getValue()).allSatisfy(target -> {
            assertThat(target.message().body()).isEqualTo(inboxBody);
            assertThat(target.message().data())
                    .containsEntry("notificationId", String.valueOf(inboxId))
                    .containsEntry("linkType", "CONCERT")
                    .containsEntry("linkId", String.valueOf(concert.getId()))
                    .containsEntry("unreadCount", "2");
        });
        assertThat(delivery.getValue().priority()).isEqualTo(PushDelivery.Priority.NORMAL);
        assertThat(delivery.getValue().ttl()).isEqualTo(Duration.ofHours(24));
    }

    @Test
    @DisplayName("같은 시각으로 다시 돌아도 푸시는 다시 나가지 않는다")
    void secondRun_doesNotPushAgain() {
        scheduler.runOnce(SEND_TIME);
        verify(sender, timeout(5000)).sendEach(anyList(), any());

        scheduler.runOnce(SEND_TIME.plusMinutes(1));

        verify(sender, after(1500).times(1)).sendEach(anyList(), any());
        assertThat(count(subscriber)).isEqualTo(1);
    }

    @Test
    @DisplayName("스윕 하나가 실패하면 그 스윕의 알림은 되돌아가 푸시도 없고, 다른 스윕의 푸시는 정상으로 나간다")
    void failingSweep_isRolledBackWithoutPush_whileOthersPush() {
        NotificationSweep failing = new NotificationSweep() {
            @Override
            public String name() {
                return "FAILING";
            }

            @Override
            public int run(LocalDateTime now, int limit) {
                recorder.record(Draft.of(bystander.getId(), NotificationType.ENTRY_OPEN, "실패할 알림", 1L,
                        NotificationType.ENTRY_OPEN.concertKey(1L)));
                throw new IllegalStateException("boom");
            }
        };
        NotificationSweepScheduler mixed = new NotificationSweepScheduler(
                List.of(failing, concertOpenSweep), transactionManager, clock, properties);

        List<SweepResult> results = mixed.runOnce(SEND_TIME);

        assertThat(results).extracting(SweepResult::name, SweepResult::failed)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("FAILING", true),
                        org.assertj.core.groups.Tuple.tuple("CONCERT_OPEN", false));
        ArgumentCaptor<List<PushTarget>> targets = targetCaptor();
        verify(sender, timeout(5000)).sendEach(targets.capture(), any());
        assertThat(targets.getValue()).extracting(PushTarget::token)
                .containsExactlyInAnyOrder(subscriberPhoneToken, subscriberTabletToken)
                .doesNotContain(bystanderToken);
        assertThat(count(bystander)).as("실패한 스윕의 알림은 되돌아간다").isZero();
        assertThat(count(subscriber)).isEqualTo(1);
        verify(sender, after(1000).times(1)).sendEach(anyList(), any());
    }

    // ---------------------------------------------------------------- 헬퍼

    @SuppressWarnings("unchecked")
    private static ArgumentCaptor<List<PushTarget>> targetCaptor() {
        return ArgumentCaptor.forClass(List.class);
    }

    private long count(Member member) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, member.getId());
    }

    private void device(Member owner, String token) {
        pushDeviceRepository.save(PushDevice.builder()
                .member(owner).token(token).platform(PushPlatform.android).build());
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
