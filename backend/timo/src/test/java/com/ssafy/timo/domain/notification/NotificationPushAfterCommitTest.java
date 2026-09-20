package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.after;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.entity.PushDevice;
import com.ssafy.timo.domain.notification.entity.PushPlatform;
import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.NotificationRecorder.Draft;
import com.ssafy.timo.global.firebase.PushNotificationSender;
import com.ssafy.timo.global.firebase.PushResult;
import com.ssafy.timo.global.firebase.PushTarget;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
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
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 푸시가 <b>커밋된 뒤에만</b> 나가는지를 실제 커밋으로 확인한다.
 *
 * <p>이 규칙이 깨지면 롤백된 결제의 알림이 기기에 뜨고, 푸시는 회수할 수 없다. 롤백되는 테스트 트랜잭션
 * 안에서는 커밋 이후 단계가 아예 오지 않아 확인할 수 없으므로, 테스트에 {@code @Transactional} 을 붙이지
 * 않고 직접 트랜잭션을 열어 커밋하거나 롤백한다. 그래서 만든 행은 테스트가 직접 지운다.
 *
 * <p>발송기를 {@code @MockitoBean} 으로 바꾸므로 공유 컨텍스트를 쓰는 {@code @IntegrationTest} 로는 못 하고
 * 이 클래스만 별도 컨텍스트를 띄운다.
 */
@SpringBootTest
@ActiveProfiles("test")
class NotificationPushAfterCommitTest {

    @MockitoBean
    private PushNotificationSender sender;

    @Autowired
    private NotificationRecorder recorder;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private PushDeviceRepository pushDeviceRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private JdbcTemplate jdbc;

    private TransactionTemplate tx;
    private Member member;
    private final AtomicReference<String> sendThread = new AtomicReference<>();

    @BeforeEach
    void setUp() {
        tx = new TransactionTemplate(transactionManager);
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        member = memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());
        pushDeviceRepository.save(PushDevice.builder()
                .member(member).token("token-" + suffix).platform(PushPlatform.android).build());

        doAnswer(invocation -> {
            sendThread.set(Thread.currentThread().getName());
            List<PushTarget> targets = invocation.getArgument(0);
            return targets.stream().map(target -> PushResult.sent(target.token())).toList();
        }).when(sender).sendEach(anyList(), any());
    }

    @AfterEach
    void cleanUp() {
        jdbc.update("delete from notification where member_id = ?", member.getId());
        jdbc.update("delete from push_device where member_id = ?", member.getId());
        jdbc.update("delete from member where member_id = ?", member.getId());
    }

    @Test
    @DisplayName("커밋되면 푸시가 나가고, 그 안에 알림 id 와 안 읽은 개수가 담기며, 별도 스레드에서 보낸다")
    void commit_sendsPushWithDataOnAnotherThread() {
        tx.executeWithoutResult(status -> recorder.record(draft("본문", 12L)));

        ArgumentCaptor<List<PushTarget>> targets = captureTargets(timeout(5000).times(1));
        PushTarget target = targets.getValue().get(0);
        Long storedId = jdbc.queryForObject(
                "select notification_id from notification where member_id = ?", Long.class, member.getId());
        assertThat(target.message().body()).isEqualTo("본문");
        assertThat(target.message().data())
                .containsEntry("notificationId", String.valueOf(storedId))
                .containsEntry("unreadCount", "1")
                .containsEntry("linkType", "CONCERT")
                .containsEntry("linkId", "12");
        assertThat(sendThread.get()).startsWith("push-");
    }

    @Test
    @DisplayName("커밋 전에는 푸시가 나가지 않는다")
    void beforeCommit_doesNotSend() {
        tx.executeWithoutResult(status -> {
            recorder.record(draft("본문", 12L));

            verify(sender, never()).sendEach(anyList(), any());
        });

        verify(sender, timeout(5000).times(1)).sendEach(anyList(), any());
    }

    @Test
    @DisplayName("롤백되면 알림도 푸시도 없다")
    void rollback_sendsNothingAndKeepsNoRow() {
        tx.executeWithoutResult(status -> {
            recorder.record(draft("본문", 12L));
            status.setRollbackOnly();
        });

        verify(sender, after(1500).never()).sendEach(anyList(), any());
        assertThat(rowCount()).isZero();
    }

    @Test
    @DisplayName("같은 알림을 다시 넣어 커밋해도 푸시는 다시 나가지 않는다")
    void duplicateCommit_doesNotSendAgain() {
        tx.executeWithoutResult(status -> recorder.record(draft("본문", 12L)));
        verify(sender, timeout(5000).times(1)).sendEach(anyList(), any());

        tx.executeWithoutResult(status -> recorder.record(draft("본문", 12L)));

        verify(sender, after(1500).times(1)).sendEach(anyList(), any());
        assertThat(rowCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("발송이 실패해도 커밋은 성공하고 알림은 알림함에 남는다")
    void sendFailure_doesNotAffectCommittedNotification() {
        doThrow(new IllegalStateException("FCM down")).when(sender).sendEach(anyList(), any());

        tx.executeWithoutResult(status -> recorder.record(draft("본문", 12L)));

        verify(sender, timeout(5000).times(1)).sendEach(anyList(), any());
        assertThat(rowCount()).isEqualTo(1);
    }

    private ArgumentCaptor<List<PushTarget>> captureTargets(org.mockito.verification.VerificationMode mode) {
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<PushTarget>> captor = ArgumentCaptor.forClass(List.class);
        verify(sender, mode).sendEach(captor.capture(), any());
        return captor;
    }

    private Draft draft(String body, Long concertId) {
        return Draft.of(member.getId(), NotificationType.ENTRY_OPEN, body, concertId,
                NotificationType.ENTRY_OPEN.concertKey(concertId));
    }

    private long rowCount() {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, member.getId());
    }
}
